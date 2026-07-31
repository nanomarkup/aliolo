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

def fetch_subject():
    print("Looking up Ukrainian Alphabet subject...")
    sql = "SELECT id, name FROM subjects WHERE lower(name) LIKE '%ukrainian%' OR lower(name) LIKE '%ukranian%' LIMIT 1"
    res = run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    try:
        data = json.loads(res.stdout)
        if not data[0]["results"]:
            raise RuntimeError("Ukrainian Alphabet subject not found.")
        return data[0]["results"][0]
    except (json.JSONDecodeError, KeyError, IndexError) as e:
        print(f"Failed to parse D1 output: {e}\nOutput was: {res.stdout[:500]}")
        sys.exit(1)

def fetch_cards(subject_id):
    print(f"Fetching cards for subject_id {subject_id}...")
    sql = f"SELECT id, answer FROM cards WHERE subject_id = '{subject_id}'"
    res = run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"])
    data = json.loads(res.stdout)
    return data[0]["results"]

def generate_audio(text: str, filepath: Path):
    # 'uk' is the language code for Ukrainian in gTTS
    tts = gTTS(text=text, lang='uk', slow=False)
    tts.save(str(filepath))

def upload_to_r2(card_id: str, filepath: Path) -> str:
    timestamp = int(time.time() * 1000)
    filename = f"global_{timestamp}.mp3"
    r2_key = f"cards/{card_id}/{filename}"
    # --remote flag ensures we upload to the actual R2 bucket instead of a local dev instance
    run_cmd(wrangler_cmd() + ["r2", "object", "put", f"{R2_BUCKET}/{r2_key}", "--file", str(filepath), "--remote"])
    return r2_key

def update_card_audio(card_id: str, public_url: str):
    # We update the base audio field
    sql = f"UPDATE cards SET audio = '{public_url}', updated_at = CURRENT_TIMESTAMP WHERE id = '{card_id}'"
    run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote"])

def main():
    TMP_DIR.mkdir(parents=True, exist_ok=True)
    
    try:
        subj = fetch_subject()
        print(f"Found subject: {subj['name']} ({subj['id']})")
        
        cards = fetch_cards(subj['id'])
        print(f"Found {len(cards)} cards to process.")
        
        for card in cards:
            card_id = card['id']
            answer = card.get('answer', '').strip()
            
            if not answer:
                print(f"Skipping card {card_id} due to empty answer.")
                continue
                
            print(f"\nProcessing '{answer}' (Card ID: {card_id})...")
            tmp_file = TMP_DIR / f"{card_id}.mp3"
            
            try:
                # 1. Generate audio
                print("  Generating audio...")
                generate_audio(answer, tmp_file)
                
                # 2. Upload to R2
                print("  Uploading to R2...")
                r2_key = upload_to_r2(card_id, tmp_file)
                public_url = f"{BASE_URL}/storage/v1/object/public/{R2_BUCKET}/{r2_key}"
                
                # 3. Update DB
                print("  Updating database...")
                update_card_audio(card_id, public_url)
                
                print(f"  -> Success: {public_url}")
                
                # Sleep a tiny bit to avoid hammering APIs
                time.sleep(1)
            except Exception as e:
                print(f"  -> Failed to process '{answer}': {e}", file=sys.stderr)
            finally:
                if tmp_file.exists():
                    tmp_file.unlink()
                    
        print("\nAll done!")
    except Exception as e:
        print(f"\nFatal Error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
