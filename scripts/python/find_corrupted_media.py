#!/usr/bin/env python3
import json
import subprocess
import shutil
import sys
import os
from pathlib import Path
from urllib.parse import urlparse

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

def get_s3_client():
    account_id = os.environ.get("R2_ACCOUNT_ID")
    access_key_id = os.environ.get("AWS_ACCESS_KEY_ID")
    secret_access_key = os.environ.get("AWS_SECRET_ACCESS_KEY")
    
    if not account_id or not access_key_id or not secret_access_key:
        print("Error: Missing required environment variables for R2 S3 API.")
        print("Please export R2_ACCOUNT_ID, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY")
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
    
    objects = set()
    for page in pages:
        if 'Contents' in page:
            for obj in page['Contents']:
                objects.add(obj['Key'])
    return objects

def extract_r2_key(url: str) -> str:
    if not url:
        return ""
    try:
        parsed = urlparse(url)
        path = parsed.path
        prefix = f"/storage/v1/object/public/{R2_BUCKET}/"
        if path.startswith(prefix):
            return path[len(prefix):]
        # Fallback for older URLs or relative paths if any
        if "cards/" in url:
            return "cards/" + url.split("cards/")[1]
    except:
        pass
    return ""

def main():
    cards = fetch_cards()
    r2_keys = list_r2_objects("cards/")
    print(f"Found {len(r2_keys)} objects in R2 under 'cards/'.")
    
    corrupted_links = []
    
    for card in cards:
        card_id = card["id"]
        
        # Process list fields
        for field in ["images_base", "images_local"]:
            val = card.get(field)
            if val:
                try:
                    urls = json.loads(val)
                    if isinstance(urls, list):
                        for i, url in enumerate(urls):
                            if isinstance(url, str):
                                key = extract_r2_key(url)
                                if key and key not in r2_keys:
                                    corrupted_links.append({
                                        "card_id": card_id,
                                        "field": field,
                                        "type": "list",
                                        "index_or_key": i,
                                        "url": url,
                                        "key": key
                                    })
                except json.JSONDecodeError:
                    pass
                    
        # Process dict fields
        for field in ["audios", "videos"]:
            val = card.get(field)
            if val:
                try:
                    urls = json.loads(val)
                    if isinstance(urls, dict):
                        for k, url in urls.items():
                            if isinstance(url, str):
                                key = extract_r2_key(url)
                                if key and key not in r2_keys:
                                    corrupted_links.append({
                                        "card_id": card_id,
                                        "field": field,
                                        "type": "dict",
                                        "index_or_key": k,
                                        "url": url,
                                        "key": key
                                    })
                except json.JSONDecodeError:
                    pass
        
        # Process string fields
        for field in ["audio", "video"]:
            url = card.get(field)
            if url and isinstance(url, str):
                key = extract_r2_key(url)
                if key and key not in r2_keys:
                    corrupted_links.append({
                        "card_id": card_id,
                        "field": field,
                        "type": "string",
                        "index_or_key": None,
                        "url": url,
                        "key": key
                    })

    if corrupted_links:
        output_file = (SCRIPT_DIR / "corrupted_media.json").resolve()
        with open(output_file, "w") as f:
            json.dump(corrupted_links, f, indent=2)
        print(f"Identified {len(corrupted_links)} corrupted media links.")
        print(f"List saved to: {output_file}")
    else:
        print("No corrupted media links found.")

if __name__ == "__main__":
    main()
