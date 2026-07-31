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
TMP_DIR = ROOT / "scripts" / ".tmp" / "unusual_musical_instruments_images"
REPORT_PATH = ROOT / "scripts" / ".tmp" / "unusual_musical_instruments_images_report.csv"
SQL_PATH = ROOT / "scripts" / ".tmp" / "create_unusual_musical_instruments_subject.sql"

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
SOURCE_URL = "https://www.carvedculture.co.uk/blogs/articles/unusual-musical-instruments"

SUBJECT_NAME = "Unusual Musical Instruments"
PILLAR_ID = 4
OWNER_ID = "usyeo7d2yzf2773"
IS_PUBLIC = 0
AGE_GROUP = "advanced"
DESCRIPTION = "Explore unusual musical instruments from around the world."
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


def fetch_existing_subject():
    sql = (
        "SELECT id, name FROM subjects "
        f"WHERE lower(name) = lower({sql_literal(SUBJECT_NAME)})"
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
    title = re.sub(r"^(\d+\.|\d+\)|\d+\s*-)\s*", "", raw_title).strip()
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
        if not re.match(r"^(\d+\.|\d+\)|\d+\s*-)\s*", heading):
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

        items.append(
            {
                "raw_heading": heading,
                "answer": normalize_answer(heading),
                "source_url": next_image[1],
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

    ext = Path(url.split("?", 1)[0]).suffix.lower()
    if ext in {".jpg", ".jpeg", ".png", ".webp"}:
        return ".jpg" if ext == ".jpeg" else ext
    return ".jpg"


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-") or "instrument"


def expand_candidate_urls(url: str):
    parsed = urllib.parse.urlsplit(url)
    path = parsed.path
    query = parsed.query
    suffix = Path(path).suffix
    stem = path[: -len(suffix)] if suffix else path

    candidates = []
    seen = set()

    def add(path_value: str, query_value: str = query):
        full = urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, path_value, query_value, parsed.fragment))
        if full not in seen:
            seen.add(full)
            candidates.append(full)

    add(path)

    stems = [stem]
    if re.search(r"_\d+x\d+$", stem):
        stems.append(re.sub(r"_\d+x\d+$", "", stem))

    for stem_value in stems:
        for ext in [suffix, ".jpg", ".jpeg", ".png", ".webp"]:
            if not ext:
                continue
            add(stem_value + ext)
            add(stem_value + ext, "")

    return candidates


def download_image(answer: str, url: str):
    last_error = None
    for candidate in expand_candidate_urls(url):
        try:
            request = urllib.request.Request(candidate, headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read()
                content_type = response.headers.get("Content-Type", "application/octet-stream")

            ext = extension_for(candidate, content_type)
            path = TMP_DIR / f"{slugify(answer)}{ext}"
            path.write_bytes(data)
            return path, content_type.split(";")[0].strip() or "application/octet-stream", candidate
        except Exception as exc:  # noqa: BLE001
            last_error = exc

    raise last_error


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


def write_sql(subject_id: str, replacements):
    lines = [
        "BEGIN;",
        "INSERT INTO subjects ("
        "id, pillar_id, owner_id, is_public, updated_at, created_at, age_group, name, description, folder_id"
        ") VALUES ("
        f"{sql_literal(subject_id)}, "
        f"{PILLAR_ID}, "
        f"{sql_literal(OWNER_ID)}, "
        f"{IS_PUBLIC}, "
        "CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, "
        f"{sql_literal(AGE_GROUP)}, "
        f"{sql_literal(SUBJECT_NAME)}, "
        f"{sql_literal(DESCRIPTION)}, "
        "NULL"
        ");",
    ]

    for item in replacements:
        lines.append(
            "INSERT INTO cards ("
            "id, subject_id, owner_id, level, test_mode, is_public, "
            "answer, answers, prompt, prompts, images_base, images_local, audio, audios, video, videos, "
            "created_at, updated_at"
            ") VALUES ("
            f"{sql_literal(item['card_id'])}, "
            f"{sql_literal(subject_id)}, "
            f"{sql_literal(OWNER_ID)}, "
            f"{item['level']}, "
            f"{sql_literal(TEST_MODE)}, "
            f"{IS_PUBLIC}, "
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

    lines.append("COMMIT;")
    SQL_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def execute_sql():
    sql_text = SQL_PATH.read_text(encoding="utf-8").splitlines()
    if sql_text and sql_text[0].strip().upper() == "BEGIN;":
        sql_text = sql_text[1:]
    if sql_text and sql_text[-1].strip().upper() == "COMMIT;":
        sql_text = sql_text[:-1]
    SQL_PATH.write_text("\n".join(sql_text) + "\n", encoding="utf-8")
    run_wrangler(["d1", "execute", DB_NAME, "--remote", "--file", str(SQL_PATH)])


def verify_subject(subject_id: str):
    sql = (
        "SELECT COUNT(*) AS total FROM cards "
        f"WHERE subject_id = {sql_literal(subject_id)}; "
        "SELECT level, COUNT(*) AS total FROM cards "
        f"WHERE subject_id = {sql_literal(subject_id)} "
        "GROUP BY level ORDER BY level;"
    )
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload


def main():
    TMP_DIR.mkdir(parents=True, exist_ok=True)

    existing = fetch_existing_subject()
    if existing:
        raise RuntimeError(f"Subject already exists: {existing[0]['id']}")

    items = extract_items(fetch_source_html())
    if len(items) != 41:
        raise RuntimeError(f"Expected 41 items with source images, found {len(items)}")

    timestamp = int(time.time() * 1000)
    subject_id = str(uuid.uuid4())
    replacements = []
    skipped = []

    for index, item in enumerate(items):
        card_id = str(uuid.uuid4())
        try:
            image_path, content_type, resolved_source_url = download_image(item["answer"], item["source_url"])
        except Exception as exc:  # noqa: BLE001
            skipped.append(
                {
                    "card_id": "",
                    "level": "",
                    "raw_heading": item["raw_heading"],
                    "answer": item["answer"],
                    "source_url": item["source_url"],
                    "source_alt": item["source_alt"],
                    "content_type": "",
                    "r2_key": "",
                    "public_url": "",
                    "status": f"skipped: {exc}",
                }
            )
            print(f"skipped\t{index + 1}\t{item['answer']}\t{exc}")
            continue

        r2_key = f"cards/{card_id}/global_{timestamp}{image_path.suffix.lower()}"
        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
        upload_file(r2_key, image_path, content_type)
        replacements.append(
            {
                "card_id": card_id,
                "level": 0,
                "raw_heading": item["raw_heading"],
                "answer": item["answer"],
                "source_url": resolved_source_url,
                "source_alt": item["source_alt"],
                "content_type": content_type,
                "r2_key": r2_key,
                "public_url": public_url,
                "status": "imported",
            }
        )
        print(f"uploaded\t{index + 1}\t{item['answer']}\t{public_url}")

    if not replacements:
        raise RuntimeError("No valid image-backed items could be downloaded from the source")

    for index, item in enumerate(replacements):
        item["level"] = level_for_position(index, len(replacements))

    write_sql(subject_id, replacements)
    execute_sql()

    with REPORT_PATH.open("w", newline="", encoding="utf-8") as handle:
        rows = replacements + skipped
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    verification = verify_subject(subject_id)
    print(f"subject_id\t{subject_id}")
    print(f"sql\t{SQL_PATH}")
    print(f"report\t{REPORT_PATH}")
    print(f"verification\t{json.dumps(verification)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
