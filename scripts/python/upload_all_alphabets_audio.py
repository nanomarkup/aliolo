#!/usr/bin/env python3
import json
import subprocess
import shutil
import sys
import os
import time
from pathlib import Path
from urllib.parse import urlparse

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

# Precise phonetic names for critical letters
PHONETIC_OVERRIDES = {
    'en': {
        'A': 'ay', 'B': 'bee', 'C': 'cee', 'D': 'dee', 'E': 'ee', 'F': 'ef', 'G': 'gee', 
        'H': 'aitch', 'I': 'eye', 'J': 'jay', 'K': 'kay', 'L': 'el', 'M': 'em', 'N': 'en', 
        'O': 'oh', 'P': 'pee', 'Q': 'cue', 'R': 'ar', 'S': 'ess', 'T': 'tee', 'U': 'u', 
        'V': 'vee', 'W': 'double-u', 'X': 'ex', 'Y': 'wye', 'Z': 'zed'
    },
    'uk': {
        'А': 'а', 'Б': 'бе', 'В': 'ве', 'Г': 'ге', 'Ґ': 'ґе', 'Д': 'де', 'Е': 'е', 'Є': 'є', 
        'Ж': 'же', 'З': 'зе', 'И': 'и', 'І': 'і', 'Ї': 'ї', 'Й': 'йот', 'К': 'ка', 'Л': 'ел', 
        'М': 'ем', 'Н': 'ен', 'О': 'о', 'П': 'пе', 'Р': 'ер', 'С': 'ес', 'Т': 'те', 'У': 'у', 
        'Ф': 'еф', 'Х': 'ха', 'Ц': 'це', 'Ч': 'че', 'Ш': 'ша', 'Щ': 'ща', 'Ь': 'м’який знак', 
        'Ю': 'ю', 'Я': 'я'
    }
}

def resolve_node_bin() -> str:
    node_bin = shutil.which("node")
    if node_bin: return node_bin
    nvm_root = Path.home() / ".config" / "nvm" / "versions" / "node"
    if nvm_root.exists():
        for v in sorted(nvm_root.iterdir(), reverse=True):
            cand = v / "bin" / "node"
            if cand.exists(): return str(cand)
    return "node"

def wrangler_cmd():
    return [resolve_node_bin(), str(WRANGLER_BIN)]

def run_cmd(cmd):
    result = subprocess.run(cmd, cwd=str(SCRIPT_DIR / "api"), capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {result.stderr or result.stdout}")
    return result

def get_subject(subject_id):
    sql = f"SELECT id, name FROM subjects WHERE id = '{subject_id}' LIMIT 1"
    res = run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    return json.loads(res.stdout)[0]["results"][0]

def get_cards(subject_id):
    sql = f"SELECT id, answer, audio FROM cards WHERE subject_id = '{subject_id}'"
    res = run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    return json.loads(res.stdout)[0]["results"]

def generate_audio(text, lang_code, filepath):
    text = text.strip()
    if lang_code in PHONETIC_OVERRIDES:
        lookup = PHONETIC_OVERRIDES[lang_code]
        if text.upper() in lookup: text = lookup[text.upper()]
    tts = gTTS(text=text, lang=lang_code, slow=False)
    tts.save(str(filepath))

def delete_from_r2(url):
    if not url or R2_BUCKET not in url: return
    try:
        key = urlparse(url).path.split(f"/{R2_BUCKET}/")[-1]
        run_cmd(wrangler_cmd() + ["r2", "object", "delete", f"{R2_BUCKET}/{key}", "--remote"])
        print(f"    - Deleted old: {key}")
    except: pass

def upload_to_r2(card_id, filepath):
    timestamp = int(time.time() * 1000)
    filename = f"global_{timestamp}.mp3"
    r2_key = f"cards/{card_id}/{filename}"
    run_cmd(wrangler_cmd() + ["r2", "object", "put", f"{R2_BUCKET}/{r2_key}", "--file", str(filepath), "--remote"])
    return r2_key

def update_card_audio(card_id, public_url):
    sql = f"UPDATE cards SET audio = '{public_url}', updated_at = CURRENT_TIMESTAMP WHERE id = '{card_id}'"
    run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote"])

def get_language_code(subject_name):
    lang_name = subject_name.replace("Alphabets", "").replace("Alphabet", "").strip()
    overrides = {"ukranian": "uk", "ukrainian": "uk", "english": "en"}
    if lang_name.lower() in overrides: return overrides[lang_name.lower()]
    langs = tts_langs()
    for code, name in langs.items():
        if name.lower() == lang_name.lower(): return code
    for code, name in langs.items():
        if lang_name.lower() in name.lower(): return code
    return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 script.py <subject_id>")
        sys.exit(1)
        
    subject_id = sys.argv[1]
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    
    try:
        subj = get_subject(subject_id)
        lang_code = get_language_code(subj['name'])
        if not lang_code:
            print(f"Skipping {subj['name']}: No lang code found.")
            return

        print(f"\nProcessing {subj['name']} ({lang_code})...")
        cards = get_cards(subject_id)
        for card in cards:
            card_id = card['id']
            answer = card.get('answer', '').strip()
            old_audio = card.get('audio')
            if not answer: continue
            
            tmp_file = TMP_DIR / f"{card_id}.mp3"
            try:
                generate_audio(answer, lang_code, tmp_file)
                if old_audio: delete_from_r2(old_audio)
                r2_key = upload_to_r2(card_id, tmp_file)
                public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
                update_card_audio(card_id, public_url)
                print(f"  '{answer}' -> OK ({new_filename if 'new_filename' in locals() else 'uploaded'})")
            except Exception as e:
                print(f"  '{answer}' -> FAILED: {e}")
            finally:
                if tmp_file.exists(): tmp_file.unlink()
    except Exception as e:
        print(f"Fatal: {e}")

if __name__ == "__main__":
    main()
