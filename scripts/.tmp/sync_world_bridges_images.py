#!/usr/bin/env python3
import csv
import html
import html.parser
import json
import mimetypes
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
TMP_DIR = ROOT / "scripts" / ".tmp" / "world_bridges_images"
REPORT_PATH = ROOT / "scripts" / ".tmp" / "world_bridges_images_report.csv"
DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
SUBJECT_ID = "849ff5de-c89c-402b-8564-69feeb5ab1da"
SOURCE_URL = "https://www.novatr.com/blog/impressive-bridges-in-the-world"

ALIASES = {
    "Millau Viaduct": "Millau Viaduct Bridge",
    "Tower Bridge": "Tower Bridge in United Kingdom",
    "Millennium Bridge": "Millenium Bridge",
    "Zaragoza Bridge Pavilion": "Zaragoza Pavilion Bridge",
    "Sheikh Zayed Bridge": "Sheikh Zayed Bridge in United Arab Emirates",
    "Henderson Waves": "Henderson Waves Bridge",
    "Pont du Gard": "Pont du Gard in France",
}


class ImageParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.images = []

    def handle_starttag(self, tag, attrs):
        if tag != "img":
            return
        data = dict(attrs)
        alt = html.unescape(data.get("alt", "")).strip()
        src = html.unescape(data.get("src", "")).strip()
        if alt and src:
            self.images.append((alt, src))


def run_wrangler(args, *, json_output=False):
    command = [
        "bash",
        "-lc",
        "source /home/vitaliinoga/.config/nvm/nvm.sh "
        "&& nvm use --lts >/dev/null "
        "&& node node_modules/wrangler/bin/wrangler.js " + " ".join(shell_quote(arg) for arg in args),
    ]
    result = subprocess.run(command, cwd=API_DIR, capture_output=True, text=True)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"exit {result.returncode}"
        raise RuntimeError(detail)
    if json_output:
        return json.loads(result.stdout)
    return result.stdout


def shell_quote(value):
    return "'" + str(value).replace("'", "'\"'\"'") + "'"


def fetch_cards():
    sql = (
        "SELECT id, answer FROM cards "
        f"WHERE subject_id = '{SUBJECT_ID}' ORDER BY answer"
    )
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"]


def fetch_source_images():
    request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "Aliolo media sync"})
    with urllib.request.urlopen(request, timeout=30) as response:
        text = response.read().decode("utf-8", "ignore")
    parser = ImageParser()
    parser.feed(text)
    return {alt: src for alt, src in parser.images}


def extension_for(url, content_type):
    content_type = (content_type or "").split(";")[0].strip().lower()
    by_type = mimetypes.guess_extension(content_type)
    if by_type == ".jpe":
        by_type = ".jpg"
    if by_type:
        return by_type

    parsed = urllib.parse.urlparse(url)
    ext = Path(parsed.path).suffix.lower()
    if ext in {".jpg", ".jpeg", ".png", ".webp"}:
        return ".jpg" if ext == ".jpeg" else ext
    return ".jpg"


def download_image(answer, url):
    request = urllib.request.Request(url, headers={"User-Agent": "Aliolo media sync"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
        content_type = response.headers.get("Content-Type", "application/octet-stream")
    ext = extension_for(url, content_type)
    filename = re.sub(r"[^a-z0-9]+", "-", answer.lower()).strip("-") + ext
    path = TMP_DIR / filename
    path.write_bytes(data)
    return path, content_type.split(";")[0].strip() or "application/octet-stream"


def upload_file(r2_key, path, content_type):
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


def update_card(card_id, public_url):
    images_json = json.dumps([public_url]).replace("'", "''")
    sql = (
        "UPDATE cards "
        f"SET images_base = '{images_json}', updated_at = CURRENT_TIMESTAMP "
        f"WHERE id = '{card_id}'"
    )
    run_wrangler(["d1", "execute", DB_NAME, "--command", sql, "--remote"])


def main():
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    cards = fetch_cards()
    source_images = fetch_source_images()
    timestamp = int(time.time() * 1000)
    rows = []

    for card in cards:
        answer = card["answer"]
        source_alt = ALIASES.get(answer, answer)
        source_url = source_images.get(source_alt)
        if not source_url:
            raise RuntimeError(f"No source image found for {answer} using alt {source_alt!r}")

        image_path, content_type = download_image(answer, source_url)
        r2_key = f"cards/{card['id']}/global_{timestamp}{image_path.suffix.lower()}"
        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
        upload_file(r2_key, image_path, content_type)
        update_card(card["id"], public_url)
        print(f"updated\t{answer}\t{public_url}")
        rows.append(
            {
                "card_id": card["id"],
                "answer": answer,
                "source_alt": source_alt,
                "source_url": source_url,
                "r2_key": r2_key,
                "public_url": public_url,
                "content_type": content_type,
            }
        )

    with REPORT_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"report\t{REPORT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
