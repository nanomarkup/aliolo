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
TMP_DIR = ROOT / "scripts" / ".tmp" / "heavy_construction_machinery_images"
REPORT_PATH = (
    ROOT / "scripts" / ".tmp" / "heavy_construction_machinery_images_report.csv"
)
DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
SUBJECT_ID = "09a77e7a-e70b-4e5f-a1f9-1ec2aaac7f0d"
SOURCE_URL = "https://www.bigrentz.com/blog/construction-equipment-names"
USER_AGENT = "Aliolo heavy construction machinery repair"

ALIASES = {
    "Compact Track Loader": "Compact Track and Multi-Terrain Loader",
}


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


def normalize_heading(text: str) -> str:
    text = html.unescape(text).replace("\xa0", " ").strip()
    text = re.sub(r"^\d+\.\s*", "", text)
    return re.sub(r"\s+", " ", text)


def fetch_source_sections() -> dict[str, str]:
    request = urllib.request.Request(SOURCE_URL, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        html_text = response.read().decode("utf-8", "ignore")

    section_pattern = re.compile(
        r"<h2[^>]*>\s*(\d+\.\s*.*?)\s*</h2>(.*?)(?=<h2[^>]*>\s*\d+\.|\Z)",
        re.IGNORECASE | re.DOTALL,
    )
    image_pattern = re.compile(r"<img[^>]+src=\"([^\"]+)\"", re.IGNORECASE)

    sections: dict[str, str] = {}
    for heading, block in section_pattern.findall(html_text):
        normalized = normalize_heading(heading)
        match = image_pattern.search(block)
        if not match:
            continue
        src = html.unescape(match.group(1)).strip()
        if not src:
            continue
        sections[normalized] = urllib.parse.urljoin(SOURCE_URL, src)
    return sections


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
    if len(cards) != 37:
        raise RuntimeError(f"Expected 37 cards, found {len(cards)}")

    source_sections = fetch_source_sections()
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
        source_heading = ALIASES.get(answer, answer)
        source_url = source_sections.get(source_heading)
        if not source_url:
            raise RuntimeError(
                f"No source image found for {answer!r} using heading {source_heading!r}"
            )

        image_path, content_type = download_image(answer, source_url)
        suffix = image_path.suffix.lower() or ".jpg"
        r2_key = f"cards/{card['id']}/global_{timestamp}{suffix}"
        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"

        upload_file(r2_key, image_path, content_type)
        update_card(card["id"], public_url)

        row = {
            "card_id": card["id"],
            "answer": answer,
            "old_url": item["old_url"],
            "source_heading": source_heading,
            "source_url": source_url,
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
