#!/usr/bin/env python3
import json
import subprocess
import shutil
import sys
import os
from pathlib import Path

DB_NAME = "aliolo-db"
SCRIPT_DIR = Path(__file__).resolve().parent.parent.parent
WRANGLER_BIN = SCRIPT_DIR / "api" / "node_modules" / "wrangler" / "bin" / "wrangler.js"

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
    return "node"

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
        raise RuntimeError(f"{' '.join(cmd)} failed: {detail}")
    return result

def fetch_card(card_id: str) -> dict:
    sql = f"SELECT id, images_base, images_local, audio, audios, video, videos FROM cards WHERE id = '{card_id}'"
    result = run_cmd(
        wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
    )
    try:
        payload = json.loads(result.stdout)
        if payload[0]["results"]:
            return payload[0]["results"][0]
        return None
    except Exception as e:
        print(f"Failed to fetch card {card_id}: {e}")
        return None

def update_card(card_id: str, updates: dict):
    set_clauses = []
    for field, value in updates.items():
        if value is None:
            set_clauses.append(f"{field} = NULL")
        else:
            escaped = value.replace("'", "''")
            set_clauses.append(f"{field} = '{escaped}'")
            
    set_clauses.append("updated_at = CURRENT_TIMESTAMP")
    set_sql = ", ".join(set_clauses)
    
    sql = f"UPDATE cards SET {set_sql} WHERE id = '{card_id}'"
    run_cmd(wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote"])

def main():
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = input("Enter the path to the corrupted media JSON file (e.g. corrupted_media.json): ").strip()
        
    if not filepath or not os.path.exists(filepath):
        print(f"Error: File '{filepath}' does not exist.")
        sys.exit(1)
        
    with open(filepath, 'r') as f:
        corrupted_links = json.load(f)
        
    if not corrupted_links:
        print("File is empty. Nothing to clean.")
        return
        
    print(f"Preparing to clean {len(corrupted_links)} corrupted links.")
    confirm = input("Are you sure you want to proceed? This will modify the database. (y/N): ").strip().lower()
    if confirm != 'y':
        print("Aborted.")
        return
        
    # Group by card_id
    cards_to_clean = {}
    for link in corrupted_links:
        card_id = link["card_id"]
        if card_id not in cards_to_clean:
            cards_to_clean[card_id] = []
        cards_to_clean[card_id].append(link)
        
    cleaned_cards = 0
    failed_cards = 0
    
    for card_id, links in cards_to_clean.items():
        print(f"Cleaning card {card_id}...")
        card = fetch_card(card_id)
        if not card:
            print(f"  Failed: Card not found.")
            failed_cards += 1
            continue
            
        updates = {}
        for link in links:
            field = link["field"]
            l_type = link["type"]
            idx_or_key = link["index_or_key"]
            url_to_remove = link["url"]
            
            # If we already have a pending update for this field, use it, else use DB value
            current_val = updates.get(field, card.get(field))
            
            if l_type == "string":
                # Set to None (NULL)
                updates[field] = None
            elif l_type == "list":
                if current_val:
                    try:
                        arr = json.loads(current_val)
                        if isinstance(arr, list) and url_to_remove in arr:
                            arr.remove(url_to_remove)
                            updates[field] = json.dumps(arr, ensure_ascii=False)
                    except:
                        pass
            elif l_type == "dict":
                if current_val:
                    try:
                        obj = json.loads(current_val)
                        if isinstance(obj, dict) and idx_or_key in obj:
                            if obj[idx_or_key] == url_to_remove:
                                del obj[idx_or_key]
                                updates[field] = json.dumps(obj, ensure_ascii=False)
                    except:
                        pass
                        
        if updates:
            try:
                update_card(card_id, updates)
                print(f"  OK: Updated fields: {', '.join(updates.keys())}")
                cleaned_cards += 1
            except Exception as e:
                print(f"  FAILED to update: {e}")
                failed_cards += 1
        else:
            print("  No updates needed (already cleaned?).")
            
    print(f"\nCleanup complete. {cleaned_cards} cards updated, {failed_cards} failed.")

if __name__ == "__main__":
    main()
