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
SUBJECT_ID = "031f918e-6afa-469b-97bc-48a65e565237" # Shapes 2D

SCRIPT_DIR = Path(__file__).resolve().parent.parent.parent
# Look for wrangler in api/node_modules or system path
WRANGLER_BIN = SCRIPT_DIR / "api" / "node_modules" / "wrangler" / "bin" / "wrangler.js"
TMP_DIR = SCRIPT_DIR / "scripts" / ".tmp"

# Map Aliolo language codes to gTTS language codes if they differ
LANG_MAP = {
    'zh': 'zh-CN',
    'tl': 'tl', # Tagalog
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
    return "node" # Fallback to system node

def wrangler_cmd() -> list[str]:
    if WRANGLER_BIN.exists():
        return [resolve_node_bin(), str(WRANGLER_BIN)]
    return ["npx", "--yes", "wrangler"]

def run_cmd(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    api_dir = SCRIPT_DIR / "api"
    result = subprocess.run(
        cmd,
        cwd=str(api_dir) if api_dir.exists() else str(SCRIPT_DIR),
        capture_output=True,
        text=True,
    )
    if check and result.returncode != 0:
        stderr = result.stderr.strip()
        stdout = result.stdout.strip()
        detail = stderr or stdout or f"exit code {result.returncode}"
        print(f"DEBUG: Command failed: {' '.join(cmd)}", flush=True)
        print(f"DEBUG: Stdout: {stdout}", flush=True)
        print(f"DEBUG: Stderr: {stderr}", flush=True)
        raise RuntimeError(f"Command failed: {detail}")
    return result

def fetch_cards():
    print(f"Fetching cards for subject_id {SUBJECT_ID}...", flush=True)
    sql = f"SELECT id, answer, answers, audios FROM cards WHERE subject_id = '{SUBJECT_ID}'"
    res = run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    try:
        data = json.loads(res.stdout)
        return data[0]["results"]
    except Exception as e:
        print(f"Failed to parse cards: {e}", flush=True)
        sys.exit(1)

def generate_audio(text: str, lang: str, filepath: Path) -> bool:
    gtts_lang = LANG_MAP.get(lang, lang)
    try:
        tts = gTTS(text=text, lang=gtts_lang, slow=False)
        tts.save(str(filepath))
        return True
    except Exception as e:
        print(f"    ! gTTS error for lang '{lang}': {e}", flush=True)
        return False

def upload_to_r2(card_id: str, lang: str, filepath: Path) -> str:
    timestamp = int(time.time() * 1000)
    filename = f"{lang}_{timestamp}.mp3"
    r2_key = f"cards/{card_id}/{filename}"
    run_cmd(wrangler_cmd() + ["r2", "object", "put", f"{R2_BUCKET}/{r2_key}", "--file", str(filepath), "--remote"])
    return f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"

def update_card_audios(card_id: str, audios_json: str):
    # Escape single quotes for SQL
    escaped_json = audios_json.replace("'", "''")
    sql = f"UPDATE cards SET audios = '{escaped_json}', updated_at = CURRENT_TIMESTAMP WHERE id = '{card_id}'"
    run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote"])

def main():
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    
    try:
        cards = fetch_cards()
        print(f"Found {len(cards)} cards to process.", flush=True)
        
        # Languages to process
        langs = ['en', 'id', 'bg', 'cs', 'da', 'de', 'et', 'es', 'fr', 'ga', 'hr', 'it', 'lv', 'lt', 'hu', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'fi', 'sv', 'tl', 'vi', 'tr', 'el', 'uk', 'ar', 'hi', 'zh', 'ja', 'ko']
        
        for card in cards:
            card_id = card['id']
            base_answer = card.get('answer', '')
            print(f"\n>>> Processing Shape: {base_answer} ({card_id})", flush=True)
            
            # Parse existing answers and audios
            try:
                answers = json.loads(card.get('answers', '{}'))
            except:
                answers = {}
            
            try:
                audios = json.loads(card.get('audios', '{}'))
                if audios is None: audios = {}
            except:
                audios = {}
            
            changed = False
            for lang in langs:
                # Get localized text, fallback to base_answer
                text = answers.get(lang, base_answer).strip()
                if not text:
                    continue
                
                print(f"  [{lang}] -> '{text}'", flush=True)
                tmp_file = TMP_DIR / f"{card_id}_{lang}.mp3"
                
                if generate_audio(text, lang, tmp_file):
                    try:
                        public_url = upload_to_r2(card_id, lang, tmp_file)
                        audios[lang] = public_url
                        changed = True
                        print(f"    + Uploaded: {public_url}", flush=True)
                    except Exception as e:
                        print(f"    ! Upload failed for {lang}: {e}", flush=True)
                    finally:
                        if tmp_file.exists():
                            tmp_file.unlink()
                
                # Tiny sleep between languages
                time.sleep(0.1)
            
            if changed:
                print(f"  Updating database for {base_answer}...", flush=True)
                update_card_audio_json = json.dumps(audios, ensure_ascii=False)
                update_card_audios(card_id, update_card_audio_json)
                print(f"  -> Successfully updated.", flush=True)
            else:
                print(f"  -> No changes for {base_answer}.", flush=True)
                
            # Sleep between cards
            time.sleep(0.5)
            
        print("\nAll shapes processed!", flush=True)
    except Exception as e:
        print(f"\nFatal Error: {e}", flush=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
