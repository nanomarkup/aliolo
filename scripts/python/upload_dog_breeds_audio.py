#!/usr/bin/env python3
import json
import subprocess
import shutil
import sys
import os
import time
import re
from pathlib import Path

try:
    from gtts import gTTS
except ImportError:
    print("Error: gTTS is not installed. Please run: pip install gTTS")
    sys.exit(1)

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"
SUBJECT_ID = "6f3f66e2-2dce-4762-b7a0-e3e1e5c7dbb1"  # Dog Breeds

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

def wrangler_cmd() -> list[str]:
    return ["npx", "wrangler"]

def run_cmd(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    api_dir = SCRIPT_DIR / "api"
    result = subprocess.run(cmd, cwd=str(api_dir), capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"{' '.join(cmd)} failed: {result.stderr or result.stdout}")
    return result

def fetch_cards():
    print(f"Fetching cards for subject_id {SUBJECT_ID}...")
    sql = f"SELECT id, answer, answers FROM cards WHERE subject_id = '{SUBJECT_ID}'"
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

def clean_name(text: str) -> str:
    # 1. Remove text inside parentheses
    text = re.sub(r'\([^)]*\)', '', text)
    # 2. Remove text inside brackets
    text = re.sub(r'\[[^\]]*\]', '', text)
    # 3. Split by delimiters: comma, semicolon, slash
    parts = re.split(r'[,，،;/]', text)
    name = parts[0].strip()
    # 4. Remove extra whitespace
    name = ' '.join(name.split())
    return name

def main():
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    try:
        cards = fetch_cards()
        print(f"Found {len(cards)} cards.")
        
        for index, card in enumerate(cards, 1):
            card_id = card['id']
            base_answer = card.get('answer', '').strip()
            localized_answers_raw = card.get('answers', '{}')
            
            try:
                localized_answers = json.loads(localized_answers_raw)
            except json.JSONDecodeError:
                localized_answers = {}
                
            print(f"\n[{index}/{len(cards)}] Processing Card ID: {card_id} (Base: {base_answer})")
            
            audios_map = {}
            base_audio_url = ""
            
            for aliolo_lang, gtts_lang in LANG_MAPPING.items():
                text_to_speak = ""
                if aliolo_lang in localized_answers:
                    text_to_speak = clean_name(localized_answers[aliolo_lang])
                
                # Fallback to English base answer
                if not text_to_speak:
                    text_to_speak = clean_name(base_answer)
                
                if not text_to_speak:
                    print(f"  [{aliolo_lang}] Skipped: empty text")
                    continue

                tmp_file = TMP_DIR / f"{card_id}_{aliolo_lang}.mp3"
                try:
                    generate_audio(text_to_speak, gtts_lang, tmp_file)
                    r2_key = upload_to_r2(card_id, aliolo_lang, tmp_file)
                    public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
                    audios_map[aliolo_lang] = public_url
                    
                    if aliolo_lang == 'en':
                        base_audio_url = public_url
                    print(f"  [{aliolo_lang}] Generated: '{text_to_speak}'")
                except Exception as e:
                    print(f"  [{aliolo_lang}] Failed to generate/upload for '{text_to_speak}': {e}")
                finally:
                    if tmp_file.exists():
                        tmp_file.unlink()
            
            if audios_map:
                print(f"  Updating database with {len(audios_map)} audio links...")
                update_card_data(card_id, audios_map, base_audio_url)
                
            # Sleep between cards
            time.sleep(0.5)
                
        print("\nAll audio files generated, uploaded, and indexed successfully!")
    except Exception as e:
        print(f"\nFatal Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
