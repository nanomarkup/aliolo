#!/usr/bin/env python3
import csv
import json
import mimetypes
import subprocess
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
TMP_DIR = ROOT / "scripts" / ".tmp" / "boxing_usyk_image"
REPORT_PATH = ROOT / "scripts" / ".tmp" / "boxing_usyk_image_report.csv"

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
USER_AGENT = "Aliolo boxing Usyk refresh"

CARD_ID = "63774b1b-82bd-4927-9c84-92b66870f7ea"
ANSWER = "Boxing"
SOURCE_PAGE = "https://commons.wikimedia.org/wiki/File:Usyk_-_Knyazev_-_0393.jpg"
SOURCE_URL = (
    "https://commons.wikimedia.org/wiki/Special:Redirect/file/"
    "Usyk%20-%20Knyazev%20-%200393.jpg?width=1800"
)


def shell_quote(value: str) -> str:
    return "'" + str(value).replace("'", "'\"'\"'") + "'"


def run_wrangler(args: list[str], *, json_output: bool = False):
    command = [
        "bash",
        "-lc",
        "source /home/vitaliinoga/.config/nvm/nvm.sh "
        "&& nvm use --lts >/dev/null "
        "&& node node_modules/wrangler/bin/wrangler.js "
        + " ".join(shell_quote(arg) for arg in args),
    ]
    result = subprocess.run(command, cwd=API_DIR, capture_output=True, text=True)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise RuntimeError(detail)
    if json_output:
        return json.loads(result.stdout)
    return result.stdout


def extension_for(url: str, content_type: str) -> str:
    normalized_type = (content_type or "").split(";")[0].strip().lower()
    guessed = mimetypes.guess_extension(normalized_type)
    if guessed == ".jpe":
        guessed = ".jpg"
    if guessed in {".jpg", ".jpeg", ".png", ".webp"}:
        return ".jpg" if guessed == ".jpeg" else guessed
    ext = Path(urllib.parse.urlparse(url).path).suffix.lower()
    if ext in {".jpg", ".jpeg", ".png", ".webp"}:
        return ".jpg" if ext == ".jpeg" else ext
    return ".jpg"


def download_image() -> tuple[Path, str]:
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": USER_AGENT})
    last_error = None
    for delay in (0, 5, 10, 20):
        if delay:
            time.sleep(delay)
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read()
                content_type = response.headers.get("Content-Type", "application/octet-stream")
            break
        except urllib.error.HTTPError as exc:
            last_error = exc
            if exc.code != 429:
                raise
    else:
        raise last_error
    ext = extension_for(SOURCE_URL, content_type)
    path = TMP_DIR / f"boxing-usyk{ext}"
    path.write_bytes(data)
    return path, content_type.split(";")[0].strip() or "application/octet-stream"


def upload_file(r2_key: str, path: Path, content_type: str) -> None:
    run_wrangler(
        [
            "r2",
            "object",
            "put",
            f"{R2_BUCKET}/{r2_key}",
            "--file",
            str(path),
            "--content-type",
            content_type,
            "--remote",
        ]
    )


def update_card(public_url: str) -> None:
    images_json = json.dumps([public_url]).replace("'", "''")
    sql = (
        "UPDATE cards "
        f"SET images_base = '{images_json}', updated_at = CURRENT_TIMESTAMP "
        f"WHERE id = '{CARD_ID}'"
    )
    run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote"])


def main() -> int:
    image_path, content_type = download_image()
    timestamp = int(time.time() * 1000)
    suffix = image_path.suffix.lower() or ".jpg"
    r2_key = f"cards/{CARD_ID}/global_{timestamp}{suffix}"
    public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
    upload_file(r2_key, image_path, content_type)
    update_card(public_url)

    row = {
        "card_id": CARD_ID,
        "answer": ANSWER,
        "source_page": SOURCE_PAGE,
        "source_url": SOURCE_URL,
        "public_url": public_url,
    }
    with REPORT_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=row.keys())
        writer.writeheader()
        writer.writerow(row)

    print(f"updated\t{ANSWER}\t{public_url}")
    print(f"report\t{REPORT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
