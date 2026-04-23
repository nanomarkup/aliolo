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
except ImportError:
    print("Error: gTTS is not installed. Please run: pip install gTTS --break-system-packages")
    sys.exit(1)

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"

# Subjects to process
SUBJECT_IDS = [
    "7c85b685-6821-4906-a0e6-e5baaa49b5bc", # Musical Instruments
    "44202921-bedf-47c7-9ac1-5d47ba522f73"  # Parts of the Human Body
]

SCRIPT_DIR = Path(__file__).resolve().parent.parent.parent
WRANGLER_BIN = SCRIPT_DIR / "api" / "node_modules" / "wrangler" / "bin" / "wrangler.js"
TMP_DIR = SCRIPT_DIR / "scripts" / ".tmp"

# Aliolo to gTTS language mapping
LANG_MAPPING = {
    'ar': 'ar', 'bg': 'bg', 'zh': 'zh-cn', 'hr': 'hr', 'cs': 'cs',
    'da': 'da', 'nl': 'nl', 'et': 'et', 'fi': 'fi', 'fr': 'fr',
    'de': 'de', 'el': 'el', 'hi': 'hi', 'hu': 'hu', 'id': 'id',
    'ga': 'ga', 'it': 'it', 'ja': 'ja', 'ko': 'ko', 'lv': 'lv',
    'lt': 'lt', 'pl': 'pl', 'pt': 'pt', 'ro': 'ro', 'sk': 'sk',
    'sl': 'sl', 'es': 'es', 'sv': 'sv', 'tl': 'tl', 'tr': 'tr',
    'uk': 'uk', 'vi': 'vi', 'en': 'en'
}

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
    raise RuntimeError("Node runtime not found.")

def wrangler_cmd() -> list[str]:
    return [resolve_node_bin(), str(WRANGLER_BIN)]

def run_cmd(cmd: list[str], check: bool = True, max_retries: int = 3) -> subprocess.CompletedProcess:
    api_dir = SCRIPT_DIR / "api"
    last_err = None
    for attempt in range(max_retries):
        result = subprocess.run(cmd, cwd=str(api_dir), capture_output=True, text=True)
        if result.returncode == 0:
            return result
        last_err = result.stderr or result.stdout
        print(f"  Warning: command failed (attempt {attempt+1}/{max_retries}): {last_err[:100]}...")
        if "Unauthorized" in last_err or "Authentication error" in last_err:
            time.sleep(5) # Wait before retry if it's an auth error
        else:
            time.sleep(2)
            
    if check:
        raise RuntimeError(f"{' '.join(cmd)} failed after {max_retries} attempts: {last_err}")
    return result

def fetch_cards(subject_id):
    print(f"Fetching cards for subject_id {subject_id}...")
    # Skip cards that already have audio to resume from failure
    sql = f"SELECT id, answer, answers FROM cards WHERE subject_id = '{subject_id}' AND (audio IS NULL OR audio = '')"
    res = run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    data = json.loads(res.stdout)
    return data[0]["results"]

def generate_audio(text: str, lang: str, filepath: Path):
    tts = gTTS(text=text, lang=lang, slow=False)
    tts.save(str(filepath))

def upload_to_r2(card_id: str, lang: str, filepath: Path) -> str:
    timestamp = int(time.time() * 1000)
    filename = f"{lang}_{timestamp}.mp3"
    r2_key = f"cards/{card_id}/{filename}"
    run_cmd(wrangler_cmd() + ["r2", "object", "put", f"{R2_BUCKET}/{r2_key}", "--file", str(filepath), "--remote"])
    return r2_key

def update_card_data(card_id: str, audios: dict, base_audio: str):
    audios_json = json.dumps(audios).replace("'", "''")
    sql = f"UPDATE cards SET audios = '{audios_json}', audio = '{base_audio}', updated_at = CURRENT_TIMESTAMP WHERE id = '{card_id}'"
    run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote"])

def main():
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    try:
        for subject_id in SUBJECT_IDS:
            print(f"\n--- Processing Subject: {subject_id} ---")
            cards = fetch_cards(subject_id)
            print(f"Found {len(cards)} cards to process.")
            
            for card in cards:
                card_id = card['id']
                base_answer = card.get('answer', '').strip()
                localized_answers_raw = card.get('answers', '{}')
                
                try:
                    localized_answers = json.loads(localized_answers_raw)
                except json.JSONDecodeError:
                    localized_answers = {}
                    
                print(f"\nProcessing Card ID: {card_id} (Base: {base_answer})")
                
                audios_map = {}
                base_audio_url = ""
                
                for aliolo_lang, gtts_lang in LANG_MAPPING.items():
                    text_to_speak = localized_answers.get(aliolo_lang, base_answer).strip()
                    if not text_to_speak:
                        continue

                    tmp_file = TMP_DIR / f"{card_id}_{aliolo_lang}.mp3"
                    try:
                        generate_audio(text_to_speak, gtts_lang, tmp_file)
                        r2_key = upload_to_r2(card_id, aliolo_lang, tmp_file)
                        public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
                        audios_map[aliolo_lang] = public_url
                        
                        if aliolo_lang == 'en':
                            base_audio_url = public_url
                            
                        print(f"  [{aliolo_lang}] OK", end=" ", flush=True)
                    except Exception as e:
                        print(f"\n  [{aliolo_lang}] Failed for '{text_to_speak}': {e}")
                    finally:
                        if tmp_file.exists(): tmp_file.unlink()
                
                if audios_map:
                    if not base_audio_url:
                        base_audio_url = list(audios_map.values())[0]
                        
                    print(f"\n  Updating database...")
                    update_card_data(card_id, audios_map, base_audio_url)
                
                # Small cool-down between cards
                time.sleep(1)
                
        print("\nAll done!")
    except Exception as e:
        print(f"\nFatal Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
