#!/usr/bin/env python3
import csv
import html
import json
import mimetypes
import re
import subprocess
import time
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
TMP_DIR = ROOT / "scripts" / ".tmp" / "famous_paintings_images"
REPORT_PATH = ROOT / "scripts" / ".tmp" / "famous_paintings_images_report.csv"
DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
SUBJECT_ID = "2f0d2ba6-165f-4b1f-9460-0fb6eba79715"
SOURCE_PAGES = [
    "https://www.topofart.com/top-100-art-reproductions.php",
    "https://www.topofart.com/top-100-art-reproductions.php/2",
    "https://www.topofart.com/top-100-art-reproductions.php/3",
    "https://www.topofart.com/top-100-art-reproductions.php/4",
    "https://www.topofart.com/top-100-art-reproductions.php/5",
]
USER_AGENT = "Aliolo famous paintings repair"


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


def fetch_cards() -> list[dict]:
    sql = (
        "SELECT id, answer, images_base FROM cards "
        f"WHERE subject_id = '{SUBJECT_ID}' ORDER BY answer"
    )
    payload = run_wrangler(
        ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
        json_output=True,
    )
    return payload[0]["results"]


def parse_images_base(raw_value) -> list[str]:
    if raw_value is None:
        return []
    if isinstance(raw_value, list):
        return [str(item) for item in raw_value if item]
    text = str(raw_value).strip()
    if not text:
        return []
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return []
    if isinstance(parsed, list):
        return [str(item) for item in parsed if item]
    return []


def current_image_url(card: dict) -> str | None:
    urls = parse_images_base(card.get("images_base"))
    return urls[0] if urls else None


def is_broken_image_url(url: str | None) -> bool:
    if not url:
        return True
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        return True
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            status = getattr(response, "status", response.getcode())
            content_type = response.headers.get("Content-Type", "").split(";")[0].lower()
            if status < 200 or status >= 300:
                return True
            if not content_type.startswith("image/"):
                return True
            response.read(1)
            return False
    except Exception:
        return True


def normalize_text(text: str) -> str:
    text = html.unescape(text).replace("\xa0", " ").strip().lower()
    text = text.replace("’", "'").replace("`", "'")
    return re.sub(r"\s+", " ", text)


def normalize_year(text: str) -> str:
    return normalize_text(text).replace(" ", "")


def card_source_key(answer: str) -> str:
    match = re.match(r"^(.*\([^()]*\)),\s+.+$", answer)
    if not match:
        raise RuntimeError(f"Unable to split title/year from answer {answer!r}")
    left = match.group(1)
    tail = re.search(r"\(([^()]*)\)\s*$", left)
    if not tail:
        raise RuntimeError(f"Unable to extract year from answer {answer!r}")
    title = left[:tail.start()].strip()
    year = tail.group(1).strip()
    return f"{normalize_text(title)}|{normalize_year(year)}"


def parse_page_title(text: str) -> tuple[str, str]:
    plain = html.unescape(re.sub(r"<[^>]+>", "", text)).strip()
    match = re.match(r"^(.*?)\s+(c\.\s*\d{3,4}(?:/\d{2})?|\d{3,4}(?:/\d{2})?)$", plain)
    if not match:
        raise RuntimeError(f"Unable to parse listing title/year from {plain!r}")
    title = match.group(1).strip()
    year = match.group(2).strip()
    return title, year


def page_source_key(title: str, year: str) -> str:
    return f"{normalize_text(title)}|{normalize_year(year)}"


def fetch_source_entries() -> dict[str, dict]:
    entries: dict[str, dict] = {}
    block_pattern = re.compile(
        r'<div class="card product-card">(.*?)</div>\s*<hr class="d-sm-none">',
        re.IGNORECASE | re.DOTALL,
    )
    title_pattern = re.compile(
        r'<h3 class="painting-title[^"]*"[^>]*>(.*?)</h3>',
        re.IGNORECASE | re.DOTALL,
    )
    href_pattern = re.compile(
        r'<a href="([^"]+/art-reproduction/[^"]+)"',
        re.IGNORECASE,
    )
    image_pattern = re.compile(
        r'(?:data-src|src)="([^"]+)"',
        re.IGNORECASE,
    )

    for page_url in SOURCE_PAGES:
        request = urllib.request.Request(page_url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=60) as response:
            text = response.read().decode("utf-8", "ignore")

        for block in block_pattern.findall(text):
            title_match = title_pattern.search(block)
            href_match = href_pattern.search(block)
            if not title_match or not href_match:
                continue

            title, year = parse_page_title(title_match.group(1))
            images = image_pattern.findall(block)
            image_url = None
            for candidate in images:
                if candidate.startswith("data:image/gif"):
                    continue
                if "topofart.com/images/" not in candidate and "cdn.topofart.com/images/" not in candidate:
                    continue
                image_url = html.unescape(candidate)
                break
            if not image_url:
                continue

            key = page_source_key(title, year)
            entries[key] = {
                "page_url": page_url,
                "detail_url": html.unescape(href_match.group(1)),
                "title": title,
                "year": year,
                "image_url": image_url,
            }
    return entries


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
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        data = response.read()
        content_type = response.headers.get("Content-Type", "application/octet-stream")
    ext = extension_for(url, content_type)
    filename = re.sub(r"[^a-z0-9]+", "-", answer.lower()).strip("-") + ext
    path = TMP_DIR / filename
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
    cards = fetch_cards()
    if len(cards) != 100:
        raise RuntimeError(f"Expected 100 cards, found {len(cards)}")

    source_entries = fetch_source_entries()
    broken_cards = []
    for card in cards:
        old_url = current_image_url(card)
        if is_broken_image_url(old_url):
            broken_cards.append({"card": card, "old_url": old_url or ""})

    if not broken_cards:
        print("No broken images detected.")
        return 0

    timestamp = int(time.time() * 1000)
    rows = []
    for item in broken_cards:
        card = item["card"]
        answer = card["answer"]
        key = card_source_key(answer)
        source_entry = source_entries.get(key)
        if not source_entry:
            raise RuntimeError(f"No source image found for {answer!r} using key {key!r}")

        image_path, content_type = download_image(answer, source_entry["image_url"])
        suffix = image_path.suffix.lower() or ".jpg"
        r2_key = f"cards/{card['id']}/global_{timestamp}{suffix}"
        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"

        upload_file(r2_key, image_path, content_type)
        update_card(card["id"], public_url)

        row = {
            "card_id": card["id"],
            "answer": answer,
            "old_url": item["old_url"],
            "source_page": source_entry["page_url"],
            "detail_url": source_entry["detail_url"],
            "source_url": source_entry["image_url"],
            "r2_key": r2_key,
            "public_url": public_url,
            "content_type": content_type,
        }
        rows.append(row)
        print(f"updated\t{answer}\t{public_url}")

    with REPORT_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"repaired\t{len(rows)}")
    print(f"report\t{REPORT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
