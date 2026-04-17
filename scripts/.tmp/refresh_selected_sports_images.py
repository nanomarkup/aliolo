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
TMP_DIR = ROOT / "scripts" / ".tmp" / "selected_sports_images"
REPORT_PATH = ROOT / "scripts" / ".tmp" / "selected_sports_images_report.csv"

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
USER_AGENT = "Aliolo selected sports image refresh"

SPORTS = [
    {
        "answer": "Athletics",
        "card_id": "675dd635-fc07-4cf5-a08f-589a1035d947",
        "source_page": "https://commons.wikimedia.org/wiki/File:Athletics_(36099350700).jpg",
        "source_url": "https://commons.wikimedia.org/wiki/Special:Redirect/file/Athletics%20%2836099350700%29.jpg?width=1600",
    },
    {
        "answer": "Judo",
        "card_id": "f8edefb2-8a95-4f9b-83a2-15724c687ac2",
        "source_page": "https://commons.wikimedia.org/wiki/File:A_judo_competition_(FL61747698).jpg",
        "source_url": "https://commons.wikimedia.org/wiki/Special:Redirect/file/A%20judo%20competition%20%28FL61747698%29.jpg?width=1600",
    },
    {
        "answer": "Boxing",
        "card_id": "63774b1b-82bd-4927-9c84-92b66870f7ea",
        "source_page": "https://commons.wikimedia.org/wiki/File:Boxing_Match.jpg",
        "source_url": "https://commons.wikimedia.org/wiki/Special:Redirect/file/Boxing%20Match.jpg?width=1400",
    },
    {
        "answer": "Softball",
        "card_id": "9abcc13a-aa15-47a2-8bba-051c69d2491a",
        "source_page": "https://commons.wikimedia.org/wiki/File:WG_W_Softball.jpg",
        "source_url": "https://commons.wikimedia.org/wiki/Special:Redirect/file/WG%20W%20Softball.jpg?width=1400",
    },
    {
        "answer": "Triathlon",
        "card_id": "b0a00b30-2f16-44ed-b3a0-2e168a73ea96",
        "source_page": "https://commons.wikimedia.org/wiki/File:Triathlon_brings_athletes_together_151017-F-IP058-179.jpg",
        "source_url": "https://commons.wikimedia.org/wiki/Special:Redirect/file/Triathlon%20brings%20athletes%20together%20151017-F-IP058-179.jpg?width=1600",
    },
    {
        "answer": "Badminton",
        "card_id": "59d0feed-090c-452b-9487-3b7fdfa1e2f7",
        "source_page": "https://commons.wikimedia.org/wiki/File:Badminton_Champions.jpg",
        "source_url": "https://commons.wikimedia.org/wiki/Special:Redirect/file/Badminton%20Champions.jpg?width=1600",
    },
    {
        "answer": "Handball",
        "card_id": "1e00374a-fba5-4203-8eaa-451602e5fc9f",
        "source_page": "https://commons.wikimedia.org/wiki/File:Handball_match.jpg",
        "source_url": "https://commons.wikimedia.org/wiki/Special:Redirect/file/Handball%20match.jpg?width=1400",
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
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    timestamp = int(time.time() * 1000)
    rows = []

    for item in SPORTS:
        image_path, content_type = download_image(item["answer"], item["source_url"])
        suffix = image_path.suffix.lower() or ".jpg"
        r2_key = f"cards/{item['card_id']}/global_{timestamp}{suffix}"
        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"

        upload_file(r2_key, image_path, content_type)
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

    print(f"updated_count\t{len(rows)}")
    print(f"report\t{REPORT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
