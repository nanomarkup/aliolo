#!/usr/bin/env python3
import json
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
API_DIR = REPO_ROOT / "api"
SQL_OUT_DIR = SCRIPT_DIR / "sql"
SH_OUT_FILE = SQL_OUT_DIR / "delete_colors_media.sh"
SQL_OUT_FILE = SQL_OUT_DIR / "delete_colors_cards.sql"
SUBJECT_ID = "0b84447d-3af3-4509-bdf6-c4e7fe822cc7"

def extract_filename(url_or_path: str) -> str:
    if not url_or_path:
        return ""
    # Just grab the last part after /
    parts = url_or_path.split("/")
    return parts[-1]

def get_cards():
    cmd = [
        "npx", "wrangler", "d1", "execute", "aliolo-db",
        "--remote",
        "--command", f"SELECT id, images_base, images_local, audio, audios, video, videos FROM cards WHERE subject_id = '{SUBJECT_ID}'",
        "--json"
    ]
    print(f"Executing: {' '.join(cmd)}")
    result = subprocess.run(cmd, cwd=API_DIR, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"Error executing wrangler: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    
    try:
        out = result.stdout.strip()
        if not out.startswith("[") and not out.startswith("{"):
            idx1 = out.find("[")
            idx2 = out.find("{")
            if idx1 == -1: idx = idx2
            elif idx2 == -1: idx = idx1
            else: idx = min(idx1, idx2)
            if idx != -1:
                out = out[idx:]
        data = json.loads(out)
        if isinstance(data, list) and len(data) > 0 and "results" in data[0]:
            return data[0]["results"]
        else:
            print("Unexpected JSON structure from wrangler:", data)
            sys.exit(1)
    except Exception as e:
        print(f"Failed to parse JSON output: {e}\nOutput was: {result.stdout}", file=sys.stderr)
        sys.exit(1)

def main():
    cards = get_cards()
    print(f"Fetched {len(cards)} cards for 'Colors' subject.")
    
    if not cards:
        print("No cards found for this subject.")
        return

    media_keys = []
    
    for card in cards:
        card_id = card.get("id")
        if not card_id:
            continue
            
        files = set()
        
        # Parse JSON fields
        for field in ["images_base", "images_local", "audios", "videos"]:
            val = card.get(field)
            if val:
                try:
                    urls = json.loads(val)
                    if isinstance(urls, list):
                        for url in urls:
                            if isinstance(url, str):
                                files.add(extract_filename(url))
                    elif isinstance(urls, dict):
                        for k, v in urls.items():
                            if isinstance(v, str):
                                files.add(extract_filename(v))
                            elif isinstance(v, list):
                                for item in v:
                                    if isinstance(item, str):
                                        files.add(extract_filename(item))
                except Exception:
                    pass
                    
        # Parse text fields
        for field in ["audio", "video"]:
            val = card.get(field)
            if val and isinstance(val, str):
                files.add(extract_filename(val))
                
        # Construct full R2 keys
        for f in files:
            if f.strip():
                media_keys.append(f"cards/{card_id}/{f}")

    print(f"Extracted {len(media_keys)} media files to delete.")
    
    SQL_OUT_DIR.mkdir(parents=True, exist_ok=True)
    
    KEYS_OUT_FILE = SQL_OUT_DIR / "media_keys.txt"
    with open(KEYS_OUT_FILE, "w", encoding="utf-8") as f:
        for key in media_keys:
            f.write(f"aliolo-media/{key}\n")
            
    # Generate SQL script for DB deletion
    with open(SQL_OUT_FILE, "w", encoding="utf-8") as f:
        f.write(f"DELETE FROM cards WHERE subject_id = '{SUBJECT_ID}';\n")
        
    print(f"Generated {KEYS_OUT_FILE}")
    print(f"Generated {SQL_OUT_FILE}")

if __name__ == "__main__":
    main()
