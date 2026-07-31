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
TMP_DIR = ROOT / "scripts" / ".tmp" / "three_sports_images"
REPORT_PATH = ROOT / "scripts" / ".tmp" / "three_sports_images_report.csv"

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
USER_AGENT = "Aliolo sports selective refresh"

SPORTS = [
    {
        "answer": "Judo",
        "card_id": "f8edefb2-8a95-4f9b-83a2-15724c687ac2",
        "source_page": "https://commons.wikimedia.org/wiki/File:Judo_(8264140354).jpg",
        "source_url": "https://commons.wikimedia.org/wiki/Special:Redirect/file/Judo%20%288264140354%29.jpg?width=1400",
    },
    {
        "answer": "Boxing",
        "card_id": "63774b1b-82bd-4927-9c84-92b66870f7ea",
        "source_page": "https://commons.wikimedia.org/wiki/File:Boxing_(49291235588).jpg",
        "source_url": "https://commons.wikimedia.org/wiki/Special:Redirect/file/Boxing%20%2849291235588%29.jpg?width=1600",
    },
    {
        "answer": "Badminton",
        "card_id": "59d0feed-090c-452b-9487-3b7fdfa1e2f7",
        "source_page": "https://commons.wikimedia.org/wiki/File:Badminton_at_the_2012_Summer_Olympics_9470.jpg",
        "source_url": "https://commons.wikimedia.org/wiki/Special:Redirect/file/Badminton%20at%20the%202012%20Summer%20Olympics%209470.jpg?width=1800",
    },
]


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


def download_image(answer: str, url: str) -> tuple[Path, str]:
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
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
    ext = extension_for(url, content_type)
    filename = "".join(char.lower() if char.isalnum() else "-" for char in answer).strip("-")
    path = TMP_DIR / f"{filename}{ext}"
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


def update_card(card_id: str, public_url: str) -> None:
    images_json = json.dumps([public_url]).replace("'", "''")
    sql = (
        "UPDATE cards "
        f"SET images_base = '{images_json}', updated_at = CURRENT_TIMESTAMP "
        f"WHERE id = '{card_id}'"
    )
    run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote"])


def main() -> int:
    timestamp = int(time.time() * 1000)
    rows = []
    for item in SPORTS:
        path, content_type = download_image(item["answer"], item["source_url"])
        suffix = path.suffix.lower() or ".jpg"
        r2_key = f"cards/{item['card_id']}/global_{timestamp}{suffix}"
        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
        upload_file(r2_key, path, content_type)
        update_card(item["card_id"], public_url)
        rows.append(
            {
                "card_id": item["card_id"],
                "answer": item["answer"],
                "source_page": item["source_page"],
                "source_url": item["source_url"],
                "public_url": public_url,
            }
        )
        print(f"updated\t{item['answer']}\t{public_url}")
    with REPORT_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)
    print(f"report\t{REPORT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
