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
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
API_DIR = ROOT / "api"
TMP_DIR = ROOT / "scripts" / ".tmp" / "food_cuisines_images"
REPORT_PATH = ROOT / "scripts" / ".tmp" / "food_cuisines_images_report.csv"

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
SUBJECT_ID = "4b210d48-c309-4c4b-ad80-24b9f8dde33e"
CATEGORY_URL = (
    "https://aroundtheworldin80cuisinesblog.wordpress.com/"
    "category/01-southern-france-and-monaco/"
)
USER_AGENT = "Aliolo food cuisines repair"

ALIASES = {
    "souvlaki and seafood platter": "souvlaki and seafood",
    "shrimp n grits and devilled eggs": "shrimp and grits and devilled eggs",
    "thali sadhya": "thali",
    "steamed whole fish": "steamed whole fish and pak choi",
    "quinoa salad": "pastel de quinoa saltena and solterito de habas",
    "tropical fruits and seafood": "sopa de mariscos",
    "roast pork with crackling": "stegt flaesk",
    "cod with egg sauce": "cod with egg and butter sauce asparagus watercress and roasted vegetables",
    "dublin lawyer": "dublin lawyer with colcannon purple cabbage salad and broccoli",
    "steak and guinness pie": "steak and guinness cottage pie with corned beef and cabbage",
    "mole poblano": "chicken mole and chiles en nogada",
    "swedish meatballs": "swedish meatballs mashed potatoes and lingonberry jam",
    "suya and plantains": "suya red red fried plantains and rice",
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


def fetch_html(url: str) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read().decode("utf-8", "ignore")


class LinkParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.current_href = None
        self.current_chunks: list[str] = []
        self.links: list[tuple[str, str]] = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.current_href = dict(attrs).get("href")
            self.current_chunks = []

    def handle_data(self, data):
        if self.current_href is not None:
            self.current_chunks.append(data)

    def handle_endtag(self, tag):
        if tag != "a" or self.current_href is None:
            return
        text = " ".join(" ".join(self.current_chunks).split()).strip()
        if text:
            self.links.append((self.current_href, html.unescape(text)))
        self.current_href = None
        self.current_chunks = []


class EventParser(html.parser.HTMLParser):
    def __init__(self):
        super().__init__()
        self.events = []
        self.capture_tag = None
        self.capture_chunks: list[str] = []

    def handle_starttag(self, tag, attrs):
        data = dict(attrs)
        if tag in {"h1", "h2", "h3", "h4"}:
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


def extract_post_links(category_html: str) -> list[tuple[str, str]]:
    parser = LinkParser()
    parser.feed(category_html)
    results = []
    seen = set()
    for href, text in parser.links:
        if not re.match(r"^\d+\.\s", text):
            continue
        absolute = urllib.parse.urljoin(CATEGORY_URL, href)
        parsed = urllib.parse.urlparse(absolute)
        if parsed.netloc != "aroundtheworldin80cuisinesblog.wordpress.com":
            continue
        if "/category/" not in parsed.path:
            continue
        if absolute in seen:
            continue
        seen.add(absolute)
        results.append((text, absolute))
    return results


def normalize_heading(text: str) -> str:
    text = html.unescape(text).replace("\xa0", " ").strip()
    text = re.sub(r"^\d+\.\s*", "", text)
    return re.sub(r"\s+", " ", text)


def normalize_key(text: str) -> str:
    text = normalize_heading(text)
    text = text.split(",", 1)[-1].strip() if "," in text else text
    text = text.replace("&", " and ")
    text = unicodedata.normalize("NFKD", text)
    text = "".join(char for char in text if not unicodedata.combining(char))
    text = text.lower()
    text = text.replace("’", "'").replace("‘", "'").replace("“", '"').replace("”", '"')
    text = re.sub(r"[()/\-–—]", " ", text)
    text = re.sub(r"[^a-z0-9+' ]+", " ", text)
    text = re.sub(r"\bde\b", "de", text)
    text = re.sub(r"\s+", " ", text).strip()
    return ALIASES.get(text, text)


def extract_dishes(post_title: str, post_url: str, html_text: str) -> list[dict]:
    parser = EventParser()
    parser.feed(html_text)
    dishes = []
    for index, event in enumerate(parser.events):
        tag = event[0]
        if tag not in {"h3", "h4"}:
            continue
        heading = normalize_heading(event[1])
        if not heading or heading.lower() == "list of cuisines":
            continue

        next_image = None
        for follow in parser.events[index + 1 :]:
            if follow[0] == "img":
                next_image = follow
                break
            if follow[0] in {"h1", "h2", "h3", "h4"}:
                break

        if not next_image:
            continue

        source_url = urllib.parse.urljoin(post_url, next_image[1])
        parsed = urllib.parse.urlparse(source_url)
        if "wordpress.com" not in parsed.netloc and "wp.com" not in parsed.netloc:
            continue

        dishes.append(
            {
                "post_title": post_title,
                "post_url": post_url,
                "heading": heading,
                "key": normalize_key(heading),
                "source_url": source_url,
                "source_alt": next_image[2],
            }
        )
    return dishes


def build_source_map() -> tuple[dict[str, dict], list[tuple[str, str]]]:
    category_html = fetch_html(CATEGORY_URL)
    post_links = extract_post_links(category_html)
    if len(post_links) != 79:
        raise RuntimeError(f"Expected 79 cuisine posts, found {len(post_links)}")

    source_map: dict[str, dict] = {}
    duplicates: list[tuple[str, str]] = []
    for post_title, post_url in post_links:
        dishes = extract_dishes(post_title, post_url, fetch_html(post_url))
        for dish in dishes:
            existing = source_map.get(dish["key"])
            if existing and existing["source_url"] != dish["source_url"]:
                duplicates.append((dish["key"], dish["heading"]))
                continue
            source_map[dish["key"]] = dish
    return source_map, duplicates


def resolve_source(answer: str, source_map: dict[str, dict]) -> dict | None:
    key = normalize_key(answer)
    if key in source_map:
        return source_map[key]

    candidates = []
    for source_key, source in source_map.items():
        if key and (key in source_key or source_key in key):
            candidates.append(source)
    if len(candidates) == 1:
        return candidates[0]
    return None


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
    filename = re.sub(r"[^a-z0-9]+", "-", normalize_key(answer)).strip("-") + ext
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
    if len(cards) != 127:
        raise RuntimeError(f"Expected 127 cards, found {len(cards)}")

    source_map, duplicates = build_source_map()
    print(f"source_dishes\t{len(source_map)}")
    if duplicates:
        print(f"duplicate_keys\t{len(duplicates)}")

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
    updated = 0
    unmatched = 0

    for item in broken_cards:
        card = item["card"]
        source = resolve_source(card["answer"], source_map)
        if not source:
            row = {
                "card_id": card["id"],
                "answer": card["answer"],
                "old_url": item["old_url"],
                "source_heading": "",
                "source_post": "",
                "source_url": "",
                "r2_key": "",
                "public_url": "",
                "status": "unmatched",
            }
            rows.append(row)
            unmatched += 1
            print(f"unmatched\t{card['answer']}")
            continue

        image_path, content_type = download_image(card["answer"], source["source_url"])
        suffix = image_path.suffix.lower() or ".jpg"
        r2_key = f"cards/{card['id']}/global_{timestamp}{suffix}"
        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"

        upload_file(r2_key, image_path, content_type)
        update_card(card["id"], public_url)

        row = {
            "card_id": card["id"],
            "answer": card["answer"],
            "old_url": item["old_url"],
            "source_heading": source["heading"],
            "source_post": source["post_title"],
            "source_url": source["source_url"],
            "r2_key": r2_key,
            "public_url": public_url,
            "status": "updated",
        }
        rows.append(row)
        updated += 1
        print(f"updated\t{card['answer']}\t{public_url}")

    with REPORT_PATH.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    print(f"broken\t{len(broken_cards)}")
    print(f"updated\t{updated}")
    print(f"unmatched\t{unmatched}")
    print(f"report\t{REPORT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
