#!/usr/bin/env python3
import json
import subprocess
import shutil
import sys
import os
from pathlib import Path

try:
    import boto3
except ImportError:
    print("Error: boto3 is not installed. Please run: pip install boto3")
    sys.exit(1)

DB_NAME = "aliolo-db"
R2_BUCKET = "aliolo-media"
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

    raise RuntimeError("Node runtime not found. Install Node or add it to PATH before running this script.")

def wrangler_cmd() -> list[str]:
    return [resolve_node_bin(), str(WRANGLER_BIN)]

def run_cmd(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess:
    # Use api/ as cwd since wrangler might need its local config
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

def fetch_cards() -> list[dict]:
    print(f"Fetching cards from D1 database '{DB_NAME}'...")
    sql = "SELECT id, images_base, images_local, audio, audios, video, videos FROM cards"
    result = run_cmd(
        wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
    )
    try:
        payload = json.loads(result.stdout)
        return payload[0]["results"]
    except (json.JSONDecodeError, KeyError, IndexError) as e:
        print(f"Failed to parse D1 output: {e}\nOutput was: {result.stdout[:500]}")
        sys.exit(1)

def fetch_profiles() -> list[dict]:
    print(f"Fetching profiles from D1 database '{DB_NAME}'...")
    sql = "SELECT avatar_url, avatar_original_url FROM profiles"
    result = run_cmd(
        wrangler_cmd() + ["d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"],
    )
    try:
        payload = json.loads(result.stdout)
        return payload[0]["results"]
    except (json.JSONDecodeError, KeyError, IndexError) as e:
        print(f"Failed to parse D1 output: {e}")
        return []

def get_s3_client():
    account_id = os.environ.get("R2_ACCOUNT_ID")
    access_key_id = os.environ.get("AWS_ACCESS_KEY_ID")
    secret_access_key = os.environ.get("AWS_SECRET_ACCESS_KEY")
    
    if not account_id or not access_key_id or not secret_access_key:
        print("Error: Missing required environment variables for R2 S3 API.")
        print("Please export R2_ACCOUNT_ID, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY")
        print("You can get these from the Cloudflare Dashboard under R2 -> Manage R2 API Tokens.")
        sys.exit(1)
        
    return boto3.client(
        service_name="s3",
        endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=access_key_id,
        aws_secret_access_key=secret_access_key,
        region_name="auto"
    )

def list_r2_objects(prefix: str):
    print(f"Listing R2 objects in bucket '{R2_BUCKET}' with prefix '{prefix}' via S3 API...")
    s3 = get_s3_client()
    paginator = s3.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket=R2_BUCKET, Prefix=prefix)
    
    objects = []
    for page in pages:
        if 'Contents' in page:
            objects.extend(page['Contents'])
    return objects

def extract_filename(url_or_path: str) -> str:
    if not url_or_path:
        return ""
    # Just grab the last segment
    return url_or_path.split('/')[-1]

def main():
    cards = fetch_cards()
    profiles = fetch_profiles()
    
    card_media_map = {}
    for card in cards:
        card_id = card["id"]
        referenced_files = set()
        
        for field in ["images_base", "images_local", "audios", "videos"]:
            val = card.get(field)
            if val:
                try:
                    urls = json.loads(val)
                    if isinstance(urls, list):
                        for url in urls:
                            if isinstance(url, str):
                                referenced_files.add(extract_filename(url))
                    elif isinstance(urls, dict):
                        for k, v in urls.items():
                            if isinstance(v, str):
                                referenced_files.add(extract_filename(v))
                            elif isinstance(v, list):
                                for item in v:
                                    if isinstance(item, str):
                                        referenced_files.add(extract_filename(item))
                except json.JSONDecodeError:
                    pass
        
        for field in ["audio", "video"]:
            val = card.get(field)
            if val:
                referenced_files.add(extract_filename(val))
                
        card_media_map[card_id] = referenced_files

    referenced_avatars = set()
    for profile in profiles:
        if profile.get("avatar_url"):
            referenced_avatars.add(extract_filename(profile["avatar_url"]))
        if profile.get("avatar_original_url"):
            referenced_avatars.add(extract_filename(profile["avatar_original_url"]))

    objects = list_r2_objects("cards/")
    total_objects = len(objects)
    print(f"Found {total_objects} objects in R2 under 'cards/'.")
    
    unused_keys = []
    for obj in objects:
        key = obj.get("Key")
        if not key:
            continue
            
        parts = key.split('/')
        # Expecting cards/{card_id}/{filename}
        if len(parts) >= 3 and parts[0] == "cards":
            card_id = parts[1]
            filename = parts[-1]
            
            if card_id not in card_media_map:
                # The folder's card_id does not exist in D1
                unused_keys.append(key)
            elif filename not in card_media_map[card_id]:
                # The card exists, but the file is not referenced
                unused_keys.append(key)

    avatar_objects = list_r2_objects("avatars/")
    print(f"Found {len(avatar_objects)} objects in R2 under 'avatars/'.")
    for obj in avatar_objects:
        key = obj.get("Key")
        if not key:
            continue
        filename = extract_filename(key)
        if filename not in referenced_avatars:
            unused_keys.append(key)

    if unused_keys:
        # Write to the project root directory
        output_file = (SCRIPT_DIR / "unused_media.txt").resolve()
        with open(output_file, "w") as f:
            for key in unused_keys:
                f.write(f"{key}\n")
        print(f"Identified {len(unused_keys)} unused media files.")
        print(f"List saved to: {output_file}")
    else:
        print("No unused media files found.")

if __name__ == "__main__":
    main()
