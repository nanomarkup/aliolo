#!/usr/bin/env python3
import csv
import html
import html.parser
import json
import mimetypes
import re
import subprocess
import time
import unicodedata
import urllib.parse
import urllib.request
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
TMP_DIR = ROOT / "scripts" / ".tmp" / "world_landmarks_images"
REPORT_PATH = ROOT / "scripts" / ".tmp" / "world_landmarks_images_report.csv"
BACKUP_PATH = ROOT / "scripts" / ".tmp" / "world_landmarks_cards_backup.json"
SQL_PATH = ROOT / "scripts" / ".tmp" / "replace_world_landmarks_cards.sql"

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
SOURCE_URL = "https://tourismteacher.com/famous-landmarks/"
SUBJECT_ID = "8efc96db-89ae-4137-91cd-6a5800b788ad"
OWNER_ID = "usyeo7d2yzf2773"
CARD_IS_PUBLIC = 1
TEST_MODE = "image_to_text"

ANSWER_OVERRIDES = {
    "Maccu Picchu": "Machu Picchu",
    "Tiananmen Square0": "Tiananmen Square",
}

SOURCE_FALLBACKS = {
    "Manolo-Gounda-St Floris National Park": [
        "https://www.worldatlas.com/r/w1200-q80/upload/c8/c9/74/blackrhino-usfws.jpg",
    ],
}


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


class LandmarkParser(html.parser.HTMLParser):
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
            srcset = data.get("srcset") or data.get("data-srcset") or ""
            alt = html.unescape(data.get("alt", "")).strip()
            if src:
                candidates = [html.unescape(src).strip()]
                for part in srcset.split(","):
                    chunk = part.strip()
                    if not chunk:
                        continue
                    candidate = chunk.split()[0].strip()
                    if candidate and candidate not in candidates:
                        candidates.append(html.unescape(candidate))
                self.events.append(("img", html.unescape(src).strip(), alt, candidates))

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
    request = urllib.request.Request(normalize_url(SOURCE_URL), headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8", "ignore")


def normalize_answer(raw_title: str) -> str:
    title = raw_title.strip()
    title = re.sub(r"^\d+[.-]\s*", "", title)
    title = re.split(r"\s+[–—-]\s+|-\s+", title, maxsplit=1)[0].strip()
    return ANSWER_OVERRIDES.get(title, title)


def extract_landmarks(source_html: str):
    parser = LandmarkParser()
    parser.feed(source_html)
    landmarks = []

    for index, event in enumerate(parser.events):
        tag = event[0]
        if tag not in {"h2", "h3", "h4"}:
            continue
        heading = event[1].strip()
        if not re.match(r"^\d+[.-]\s*", heading):
            continue

        next_image = None
        for follow in parser.events[index + 1:]:
            if follow[0] == "img":
                next_image = follow
                break
            if follow[0] in {"h2", "h3", "h4"}:
                break
        if not next_image:
            raise RuntimeError(f"No image found after heading: {heading}")

        source_number_match = re.match(r"^(\d+)[.-]\s*", heading)
        source_number = int(source_number_match.group(1)) if source_number_match else None
        answer = normalize_answer(heading)
        landmarks.append(
            {
                "source_number": source_number,
                "raw_heading": heading,
                "answer": answer,
                "source_url": next_image[1],
                "source_alt": next_image[2],
                "source_candidates": next_image[3],
            }
        )

    return landmarks


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
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-") or "landmark"


def normalize_url(url: str) -> str:
    parsed = urllib.parse.urlsplit(url)
    path = urllib.parse.quote(unicodedata.normalize("NFC", parsed.path), safe="/%")
    query = urllib.parse.quote_plus(parsed.query, safe="=&%")
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, path, query, parsed.fragment))


def expand_candidate_urls(urls):
    if isinstance(urls, str):
        urls = [urls]

    ordered = []
    seen = set()

    def add(candidate):
        if candidate and candidate not in seen:
            seen.add(candidate)
            ordered.append(candidate)

    for url in urls:
        add(url)
        parsed = urllib.parse.urlsplit(url)
        path = parsed.path
        suffix = Path(path).suffix
        stem = path[: -len(suffix)] if suffix else path
        stem_no_size = re.sub(r"-\d+x\d+$", "", stem)
        stems = [
            stem,
            stem_no_size,
            re.sub(r"-\d+$", "", stem),
            re.sub(r"-\d+$", "", stem_no_size),
        ]

        for raw_stem in stems:
            candidate_stem = raw_stem.strip()
            if not candidate_stem:
                continue
            for ext in [suffix, ".jpg", ".jpeg", ".png", ".webp"]:
                if not ext:
                    continue
                updated = urllib.parse.urlunsplit(
                    (parsed.scheme, parsed.netloc, candidate_stem + ext, parsed.query, parsed.fragment)
                )
                add(updated)

    return ordered


def download_image(answer: str, urls):
    last_error = None
    preferred_urls = SOURCE_FALLBACKS.get(answer, []) + list(urls if isinstance(urls, list) else [urls])
    for url in expand_candidate_urls(preferred_urls):
        try:
            request = urllib.request.Request(normalize_url(url), headers={"User-Agent": "Mozilla/5.0"})
            with urllib.request.urlopen(request, timeout=60) as response:
                data = response.read()
                content_type = response.headers.get("Content-Type", "application/octet-stream")
            ext = extension_for(url, content_type)
            path = TMP_DIR / f"{slugify(answer)}{ext}"
            path.write_bytes(data)
            return path, content_type.split(";")[0].strip() or "application/octet-stream", url
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


def write_sql(replacements):
    lines = [
        f"DELETE FROM cards WHERE subject_id = {sql_literal(SUBJECT_ID)};",
    ]
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
    landmarks = extract_landmarks(source_html)
    if len(landmarks) != 191:
        raise RuntimeError(f"Expected 191 landmarks from source, found {len(landmarks)}")

    timestamp = int(time.time() * 1000)
    replacements = []

    for level, landmark in enumerate(landmarks, start=1):
        card_id = str(uuid.uuid4())
        image_path, content_type, resolved_source_url = download_image(
            landmark["answer"], landmark["source_candidates"]
        )
        r2_key = f"cards/{card_id}/global_{timestamp}{image_path.suffix.lower()}"
        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
        upload_file(r2_key, image_path, content_type)
        replacements.append(
            {
                "card_id": card_id,
                "level": level,
                "source_number": landmark["source_number"],
                "raw_heading": landmark["raw_heading"],
                "answer": landmark["answer"],
                "source_url": resolved_source_url,
                "source_alt": landmark["source_alt"],
                "content_type": content_type,
                "r2_key": r2_key,
                "public_url": public_url,
            }
        )
        print(f"uploaded\t{level}\t{landmark['answer']}\t{public_url}")

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
