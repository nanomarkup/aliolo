#!/usr/bin/env python3
import csv
import html
import html.parser
import json
import math
import mimetypes
import re
import subprocess
import time
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
TMP_DIR = ROOT / "scripts" / ".tmp" / "musical_instruments_images"
REPORT_PATH = ROOT / "scripts" / ".tmp" / "musical_instruments_images_report.csv"
BACKUP_PATH = ROOT / "scripts" / ".tmp" / "musical_instruments_cards_backup.json"
SQL_PATH = ROOT / "scripts" / ".tmp" / "replace_musical_instruments_cards.sql"

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
SOURCE_URL = "https://richmondmom.com/popular-musical-instruments-around-the-world/"
SUBJECT_ID = "7c85b685-6821-4906-a0e6-e5baaa49b5bc"
OWNER_ID = "usyeo7d2yzf2773"
CARD_IS_PUBLIC = 1
TEST_MODE = "image_to_text"


def shell_quote(value: str) -> str:
    return "'" + str(value).replace("'", "'\"'\"'") + "'"


def sql_literal(value):
    if value is None:
        return "NULL"
    return "'" + str(value).replace("'", "''") + "'"


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


def fetch_existing_cards():
    sql = (
        "SELECT id, subject_id, owner_id, level, test_mode, is_public, "
        "answer, answers, prompt, prompts, images_base, images_local, audio, audios, video, videos, "
        "created_at, updated_at "
        f"FROM cards WHERE subject_id = {sql_literal(SUBJECT_ID)} ORDER BY level, answer, id"
    )
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"]


class SourceParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.events = []
        self.capture_tag = None
        self.capture_chunks = []

    def handle_starttag(self, tag, attrs):
        data = dict(attrs)
        if tag in {"h2", "h3", "h4"}:
            self.capture_tag = tag
            self.capture_chunks = []
            return
        if tag == "img":
            src = data.get("src") or data.get("data-src") or data.get("data-lazy-src")
            alt = html.unescape(data.get("alt", "")).strip()
            if src:
                self.events.append(("img", html.unescape(src).strip(), alt))

    def handle_data(self, data):
        if self.capture_tag:
            self.capture_chunks.append(data)

    def handle_endtag(self, tag):
        if tag != self.capture_tag:
            return
        text = html.unescape(" ".join(" ".join(self.capture_chunks).split())).strip()
        self.events.append((tag, text))
        self.capture_tag = None
        self.capture_chunks = []


def fetch_source_html():
    request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8", "ignore")


def normalize_answer(raw_title: str) -> str:
    title = re.sub(r"^\d+\.\s*", "", raw_title).strip()
    return title.replace("_", " ")


def extract_items(source_html: str):
    parser = SourceParser()
    parser.feed(source_html)
    items = []

    for index, event in enumerate(parser.events):
        tag = event[0]
        if tag not in {"h2", "h3", "h4"}:
            continue
        heading = event[1].strip()
        if not re.match(r"^\d+\.\s+", heading):
            continue

        next_image = None
        for follow in parser.events[index + 1:]:
            if follow[0] == "img":
                next_image = follow
                break
            if follow[0] in {"h2", "h3", "h4"}:
                break

        if not next_image:
            continue

        image_url = next_image[1]
        if "richmondmom.com/wp-content/uploads" not in image_url and "cdn.richmondmom.com/wp-content/uploads" not in image_url:
            continue

        items.append(
            {
                "source_number": int(re.match(r"^(\d+)\.", heading).group(1)),
                "raw_heading": heading,
                "answer": normalize_answer(heading),
                "source_url": image_url,
                "source_alt": next_image[2],
            }
        )

    return items


def extension_for(url: str, content_type: str) -> str:
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


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-") or "instrument"


def download_image(answer: str, url: str):
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
        content_type = response.headers.get("Content-Type", "application/octet-stream")

    ext = extension_for(url, content_type)
    path = TMP_DIR / f"{slugify(answer)}{ext}"
    path.write_bytes(data)
    return path, content_type.split(";")[0].strip() or "application/octet-stream"


def upload_file(r2_key: str, path: Path, content_type: str):
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


def level_for_position(index: int, total: int) -> int:
    first_cut = math.ceil(total / 3)
    second_cut = math.ceil((2 * total) / 3)
    if index < first_cut:
        return 1
    if index < second_cut:
        return 2
    return 3


def write_sql(replacements):
    lines = [f"DELETE FROM cards WHERE subject_id = {sql_literal(SUBJECT_ID)};"]
    for item in replacements:
        lines.append(
            "INSERT INTO cards ("
            "id, subject_id, owner_id, level, test_mode, is_public, "
            "answer, answers, prompt, prompts, images_base, images_local, audio, audios, video, videos, "
            "created_at, updated_at"
            ") VALUES ("
            f"{sql_literal(item['card_id'])}, "
            f"{sql_literal(SUBJECT_ID)}, "
            f"{sql_literal(OWNER_ID)}, "
            f"{item['level']}, "
            f"{sql_literal(TEST_MODE)}, "
            f"{CARD_IS_PUBLIC}, "
            f"{sql_literal(item['answer'])}, "
            f"{sql_literal(json.dumps({}))}, "
            f"{sql_literal('')}, "
            f"{sql_literal(json.dumps({}))}, "
            f"{sql_literal(json.dumps([item['public_url']]))}, "
            f"{sql_literal(json.dumps({}))}, "
            f"{sql_literal('')}, "
            f"{sql_literal(json.dumps({}))}, "
            f"{sql_literal('')}, "
            f"{sql_literal(json.dumps({}))}, "
            "CURRENT_TIMESTAMP, CURRENT_TIMESTAMP"
            ");"
        )
    SQL_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def execute_sql_file():
    run_wrangler(["d1", "execute", DB_NAME, "--remote", "--file", str(SQL_PATH)])


def fetch_final_count():
    sql = f"SELECT COUNT(*) AS total FROM cards WHERE subject_id = {sql_literal(SUBJECT_ID)}"
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return int(payload[0]["results"][0]["total"])


def main():
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    existing_cards = fetch_existing_cards()
    BACKUP_PATH.write_text(json.dumps(existing_cards, indent=2), encoding="utf-8")

    source_html = fetch_source_html()
    items = extract_items(source_html)
    if len(items) != 24:
        raise RuntimeError(f"Expected 24 items with images from source, found {len(items)}")

    timestamp = int(time.time() * 1000)
    replacements = []

    for index, item in enumerate(items):
        card_id = str(uuid.uuid4())
        image_path, content_type = download_image(item["answer"], item["source_url"])
        r2_key = f"cards/{card_id}/global_{timestamp}{image_path.suffix.lower()}"
        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
        upload_file(r2_key, image_path, content_type)
        replacements.append(
            {
                "card_id": card_id,
                "level": level_for_position(index, len(items)),
                "source_number": item["source_number"],
                "raw_heading": item["raw_heading"],
                "answer": item["answer"],
                "source_url": item["source_url"],
                "source_alt": item["source_alt"],
                "content_type": content_type,
                "r2_key": r2_key,
                "public_url": public_url,
            }
        )
        print(f"uploaded\t{index + 1}\t{item['answer']}\t{public_url}")

    write_sql(replacements)
    execute_sql_file()

    final_count = fetch_final_count()
    if final_count != len(replacements):
        raise RuntimeError(f"Expected {len(replacements)} cards after import, found {final_count}")

    with REPORT_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=replacements[0].keys())
        writer.writeheader()
        writer.writerows(replacements)

    print(f"backup\t{BACKUP_PATH}")
    print(f"sql\t{SQL_PATH}")
    print(f"report\t{REPORT_PATH}")
    print(f"replaced\t{len(existing_cards)}\twith\t{len(replacements)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
