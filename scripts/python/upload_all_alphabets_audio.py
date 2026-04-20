#!/usr/bin/env python3
import json
import subprocess
import shutil
import sys
import os
import time
from pathlib import Path

try:
    from gtts import gTTS
    from gtts.lang import tts_langs
except ImportError:
    print("Error: gTTS is not installed. Please run: pip install gTTS --break-system-packages")
    sys.exit(1)

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"

SCRIPT_DIR = Path(__file__).resolve().parent.parent.parent
WRANGLER_BIN = SCRIPT_DIR / "api" / "node_modules" / "wrangler" / "bin" / "wrangler.js"
TMP_DIR = SCRIPT_DIR / "scripts" / ".tmp"

def resolve_node_bin() -> str:
    node_bin = shutil.which("node")
    if node_bin:
        return node_bin

    nvm_root = Path.home() / ".config" / "nvm" / "versions" / "node"
    if nvm_root.exists():
        versions = sorted(nvm_root.iterdir(), reverse=True)
        for version_dir in versions:
            candidate = version_dir / "bin" / "node"
            if candidate.exists():
                return str(candidate)

    raise RuntimeError("Node runtime not found. Install Node or add it to PATH before running this script.")

def wrangler_cmd() -> list[str]:
    return [resolve_node_bin(), str(WRANGLER_BIN)]

def run_cmd(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    api_dir = SCRIPT_DIR / "api"
    result = subprocess.run(
        cmd,
        cwd=str(api_dir),
        capture_output=True,
        text=True,
    )
    if check and result.returncode != 0:
        stderr = result.stderr.strip()
        stdout = result.stdout.strip()
        detail = stderr or stdout or f"exit code {result.returncode}"
        raise RuntimeError(f"{' '.join(cmd)} failed: {detail}")
    return result

def fetch_subjects():
    print("Fetching all alphabet subjects...")
    sql = "SELECT id, name FROM subjects WHERE name LIKE '%Alphabet%'"
    res = run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    try:
        data = json.loads(res.stdout)
        return data[0]["results"]
    except (json.JSONDecodeError, KeyError, IndexError) as e:
        print(f"Failed to parse D1 output: {e}\nOutput was: {res.stdout[:500]}")
        sys.exit(1)

def fetch_cards(subject_id):
    sql = f"SELECT id, answer, audio FROM cards WHERE subject_id = '{subject_id}'"
    res = run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    data = json.loads(res.stdout)
    return data[0]["results"]

def generate_audio(text: str, lang_code: str, filepath: Path):
    tts = gTTS(text=text, lang=lang_code, slow=False)
    tts.save(str(filepath))

def upload_to_r2(card_id: str, filepath: Path) -> str:
    timestamp = int(time.time() * 1000)
    filename = f"global_{timestamp}.mp3"
    r2_key = f"cards/{card_id}/{filename}"
    run_cmd(wrangler_cmd() + ["r2", "object", "put", f"{R2_BUCKET}/{r2_key}", "--file", str(filepath), "--remote"])
    return r2_key

def update_card_audio(card_id: str, public_url: str):
    sql = f"UPDATE cards SET audio = '{public_url}', updated_at = CURRENT_TIMESTAMP WHERE id = '{card_id}'"
    run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote"])

def get_language_code(subject_name: str) -> str:
    lang_name = subject_name.replace("Alphabets", "").replace("Alphabet", "").strip()
    
    overrides = {
        "ukranian": "uk",
        "ukrainian": "uk",
        "english": "en",
        "brazilian portuguese": "pt",
        "mexican spanish": "es",
        "korean": "ko",
        "japanese": "ja",
        "chinese": "zh-cn",
        "chinese (mandarin)": "zh-cn"
    }
    
    if lang_name.lower() in overrides:
        return overrides[lang_name.lower()]
        
    langs = tts_langs()
    
    for code, name in langs.items():
        if name.lower() == lang_name.lower():
            return code
            
    for code, name in langs.items():
        if lang_name.lower() in name.lower() or name.lower() in lang_name.lower():
            return code
            
    return None

def main():
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    
    try:
        subjects = fetch_subjects()
        print(f"Found {len(subjects)} subjects containing 'Alphabet'.")
        
        skip_names = ["English Alphabet", "Ukrainian Alphabet", "Ukranian Alphabet", "Ukranian Alphabets"]
        subjects_to_process = [s for s in subjects if s['name'] not in skip_names]
        
        print(f"Subjects to process: {len(subjects_to_process)}")
        
        for subj in subjects_to_process:
            print(f"\n--- Processing Subject: {subj['name']} ({subj['id']}) ---")
            
            lang_code = get_language_code(subj['name'])
            if not lang_code:
                print(f"Skipping '{subj['name']}': Could not determine gTTS language code.")
                continue
                
            print(f"Mapped '{subj['name']}' to language code: '{lang_code}'")
            
            cards = fetch_cards(subj['id'])
            print(f"Found {len(cards)} cards.")
            
            for card in cards:
                card_id = card['id']
                answer = card.get('answer', '').strip()
                
                if not answer:
                    print(f"Skipping card {card_id} due to empty answer.")
                    continue
                    
                print(f"  Processing '{answer}' (Card ID: {card_id})...")
                tmp_file = TMP_DIR / f"{card_id}.mp3"
                
                try:
                    generate_audio(answer, lang_code, tmp_file)
                    r2_key = upload_to_r2(card_id, tmp_file)
                    public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
                    update_card_audio(card_id, public_url)
                    print(f"    -> Success: {public_url}")
                    time.sleep(1)
                except Exception as e:
                    print(f"    -> Failed to process '{answer}': {e}", file=sys.stderr)
                finally:
                    if tmp_file.exists():
                        tmp_file.unlink()
                        
        print("\nAll done!")
    except Exception as e:
        print(f"\nFatal Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
