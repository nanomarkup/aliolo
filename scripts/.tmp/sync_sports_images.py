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
TMP_DIR = ROOT / "scripts" / ".tmp" / "sports_images"
REPORT_PATH = ROOT / "scripts" / ".tmp" / "sports_images_report.csv"

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
SUBJECT_ID = "1c58e149-e9f8-4edb-876a-e148b19f6c82"
USER_AGENT = "Aliolo sports image refresh"

IGNORED_ANSWERS = {
    "Archery",
    "Badminton",
    "Baseball",
    "Bobsleigh",
    "Bowling",
    "Canoeing",
    "Cricket",
    "Darts",
    "Fencing",
    "Gymnastics",
    "Lacrosse",
    "Motocross",
    "Rowing",
    "Sailing",
    "Skateboarding",
    "Skiing",
    "Snooker",
    "Snowboarding",
    "Taekwondo",
    "Tennis",
    "Volleyball",
    "Wrestling",
}

PAGE_TITLES = {
    "American Football": ["American football"],
    "Athletics": ["Track and field"],
    "Basketball": ["Basketball"],
    "Boxing": ["Boxing"],
    "Cycling": ["Road bicycle racing", "Cycle sport", "Cycling"],
    "Equestrian": ["Equestrianism"],
    "Field Hockey": ["Field hockey"],
    "Football": ["Association football"],
    "Formula 1 Racing": ["Formula racing", "Formula One"],
    "Golf": ["Golf"],
    "Handball": ["Handball"],
    "Horse Racing": ["Horse racing"],
    "Ice Hockey": ["Ice hockey"],
    "Judo": ["Judo"],
    "Kitesurfing": ["Kitesurfing", "Kiteboarding"],
    "MMA": ["Mixed martial arts"],
    "Muay Thai": ["Muay Thai"],
    "Rugby": ["Rugby union"],
    "Rugby League": ["Rugby league"],
    "Softball": ["Softball"],
    "Speed Skating": ["Speed skating"],
    "Squash": ["Squash (sport)", "Squash"],
    "Surfing": ["Surfing"],
    "Swimming": ["Swimming (sport)", "Swimming"],
    "Table Tennis": ["Table tennis"],
    "Triathlon": ["Triathlon"],
    "Water Polo": ["Water polo"],
    "Weightlifting": ["Olympic weightlifting", "Weightlifting"],
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


def fetch_summary(page_title: str) -> dict:
    url = (
        "https://en.wikipedia.org/api/rest_v1/page/summary/"
        + urllib.parse.quote(page_title, safe="")
    )
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def preferred_wikimedia_thumbnail(url: str, width: int = 1280) -> str:
    marker = "/thumb/"
    width_marker = "px-"
    if marker not in url or width_marker not in url:
        return url
    prefix, tail = url.split(marker, 1)
    parts = tail.split("/")
    if len(parts) < 4:
        return url
    filename = parts[-1]
    width_part = filename.split(width_marker, 1)
    if len(width_part) != 2:
        return url
    actual_name = width_part[1]
    base_parts = parts[:-1]
    return prefix + marker + "/".join(base_parts) + f"/{width}px-{actual_name}"


def choose_image(page_title: str) -> tuple[str, str]:
    payload = fetch_summary(page_title)
    thumbnail_url = (payload.get("thumbnail") or {}).get("source")
    source_url = preferred_wikimedia_thumbnail(thumbnail_url) if thumbnail_url else None
    if not source_url:
        source_url = (payload.get("originalimage") or {}).get("source")
    if not source_url:
        raise RuntimeError(f"No image on summary page {page_title!r}")
    return payload.get("title") or page_title, source_url


def resolve_source(answer: str) -> tuple[str, str]:
    page_titles = PAGE_TITLES.get(answer)
    if not page_titles:
        raise RuntimeError(f"No source page mapping for {answer!r}")
    last_error = None
    for page_title in page_titles:
        try:
            return choose_image(page_title)
        except Exception as exc:  # noqa: BLE001
            last_error = exc
    raise RuntimeError(f"Unable to resolve image for {answer!r}: {last_error}")


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


def download_image(answer: str, source_url: str) -> tuple[Path, str]:
    request = urllib.request.Request(source_url, headers={"User-Agent": USER_AGENT})
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
    suffix = extension_for(source_url, content_type)
    filename = (
        "".join(char.lower() if char.isalnum() else "-" for char in answer)
        .strip("-")
        .replace("--", "-")
    )
    path = TMP_DIR / f"{filename}{suffix}"
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
    targets = [card for card in cards if card["answer"] not in IGNORED_ANSWERS]
    if len(targets) != 28:
        raise RuntimeError(f"Expected 28 target sports, found {len(targets)}")

    timestamp = int(time.time() * 1000)
    rows = []

    for card in targets:
        source_title, source_url = resolve_source(card["answer"])
        image_path, content_type = download_image(card["answer"], source_url)
        suffix = image_path.suffix.lower() or ".jpg"
        r2_key = f"cards/{card['id']}/global_{timestamp}{suffix}"
        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"

        upload_file(r2_key, image_path, content_type)
        update_card(card["id"], public_url)

        row = {
            "card_id": card["id"],
            "answer": card["answer"],
            "source_title": source_title,
            "source_url": source_url,
            "r2_key": r2_key,
            "public_url": public_url,
            "content_type": content_type,
        }
        rows.append(row)
        print(f"updated\t{card['answer']}\t{public_url}")

    with REPORT_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"updated_count\t{len(rows)}")
    print(f"report\t{REPORT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
