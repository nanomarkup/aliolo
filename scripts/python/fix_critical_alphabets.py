#!/usr/bin/env python3
import json
import subprocess
import shutil
import sys
import os
import time
from pathlib import Path
from urllib.parse import urlparse

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
BASE_URL = "https://aliolo.com"

try:
    from gtts import gTTS
except ImportError:
    print("Error: gTTS is not installed.")
    sys.exit(1)

SCRIPT_DIR = Path(__file__).resolve().parent.parent.parent
WRANGLER_BIN = SCRIPT_DIR / "api" / "node_modules" / "wrangler" / "bin" / "wrangler.js"
TMP_DIR = SCRIPT_DIR / "scripts" / ".tmp"

# Precise phonetic names for letters to force correct gTTS pronunciation
UKRAINIAN_PHONETIC = {
    'А': 'а', 'Б': 'бе', 'В': 'ве', 'Г': 'ге', 'Ґ': 'ґе', 'Д': 'де', 'Е': 'е', 'Є': 'є', 
    'Ж': 'же', 'З': 'зе', 'И': 'и', 'І': 'і', 'Ї': 'ї', 'Й': 'йот', 'К': 'ка', 'Л': 'ел', 
    'М': 'ем', 'Н': 'ен', 'О': 'о', 'П': 'пе', 'Р': 'ер', 'С': 'ес', 'Т': 'те', 'У': 'у', 
    'Ф': 'еф', 'Х': 'ха', 'Ц': 'це', 'Ч': 'че', 'Ш': 'ша', 'Щ': 'ща', 'Ь': 'м’який знак', 
    'Ю': 'ю', 'Я': 'я'
}

ENGLISH_PHONETIC = {
    'A': 'ay', 'B': 'bee', 'C': 'cee', 'D': 'dee', 'E': 'ee', 'F': 'ef', 'G': 'gee', 
    'H': 'aitch', 'I': 'eye', 'J': 'jay', 'K': 'kay', 'L': 'el', 'M': 'em', 'N': 'en', 
    'O': 'oh', 'P': 'pee', 'Q': 'cue', 'R': 'ar', 'S': 'ess', 'T': 'tee', 'U': 'u', 
    'V': 'vee', 'W': 'double-u', 'X': 'ex', 'Y': 'wye', 'Z': 'zed'
}

def resolve_node_bin() -> str:
    node_bin = shutil.which("node")
    if node_bin: return node_bin
    nvm_root = Path.home() / ".config" / "nvm" / "versions" / "node"
    if nvm_root.exists():
        for version_dir in sorted(nvm_root.iterdir(), reverse=True):
            candidate = version_dir / "bin" / "node"
            if candidate.exists(): return str(candidate)
    return "node"

def wrangler_cmd() -> list[str]:
    return [resolve_node_bin(), str(WRANGLER_BIN)]

def run_cmd(cmd: list[str]) -> subprocess.CompletedProcess:
    result = subprocess.run(cmd, cwd=str(SCRIPT_DIR / "api"), capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {result.stderr or result.stdout}")
    return result

def get_subjects():
    sql = "SELECT id, name FROM subjects WHERE name IN ('English Alphabet', 'Ukrainian Alphabet')"
    res = run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    return json.loads(res.stdout)[0]["results"]

def get_cards(subject_id):
    sql = f"SELECT id, answer, audio FROM cards WHERE subject_id = '{subject_id}'"
    res = run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    return json.loads(res.stdout)[0]["results"]

def main():
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    subjects = get_subjects()
    
    for subj in subjects:
        subject_id = subj['id']
        lang = 'uk' if 'Ukrainian' in subj['name'] else 'en'
        phonetic_map = UKRAINIAN_PHONETIC if lang == 'uk' else ENGLISH_PHONETIC
        
        print(f"\n--- REFRESHING: {subj['name']} ({lang}) ---")
        cards = get_cards(subject_id)
        
        for card in cards:
            card_id = card['id']
            answer = card['answer'].strip().upper()
            old_url = card.get('audio')
            
            # 1. Determine pronunciation text
            text_to_speak = phonetic_map.get(answer, answer)
            print(f"  Processing '{answer}' as '{text_to_speak}'...")
            
            # 2. Delete old file from R2
            if old_url and R2_BUCKET in old_url:
                key = urlparse(old_url).path.split(f"/{R2_BUCKET}/")[-1]
                try:
                    run_cmd(wrangler_cmd() + ["r2", "object", "delete", f"{R2_BUCKET}/{key}", "--remote"])
                    print(f"    - Deleted: {key}")
                except:
                    print(f"    - (Skip) Could not delete: {key}")

            # 3. Generate new audio
            tmp_file = TMP_DIR / f"{card_id}.mp3"
            tts = gTTS(text=text_to_speak, lang=lang, slow=False)
            tts.save(str(tmp_file))
            
            # 4. Upload new file with unique timestamp
            new_filename = f"global_{int(time.time() * 1000)}.mp3"
            r2_key = f"cards/{card_id}/{new_filename}"
            run_cmd(wrangler_cmd() + ["r2", "object", "put", f"{R2_BUCKET}/{r2_key}", "--file", str(tmp_file), "--remote"])
            
            # 5. Update Database
            new_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
            sql = f"UPDATE cards SET audio = '{new_url}', updated_at = CURRENT_TIMESTAMP WHERE id = '{card_id}'"
            run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote"])
            
            print(f"    - Success: {new_filename}")
            if tmp_file.exists(): tmp_file.unlink()
            time.sleep(0.5)

    print("\nRefresh complete!")

if __name__ == "__main__":
    main()
