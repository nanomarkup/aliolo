#!/usr/bin/env python3
import sys
import os
from pathlib import Path

try:
    import boto3
except ImportError:
    print("Error: boto3 is not installed. Please run: pip install boto3")
    sys.exit(1)

R2_BUCKET = "aliolo-media"

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

def main():
    if len(sys.argv) > 1:
        filepath = sys.argv[1]
    else:
        filepath = input("Enter the path to the unused media list (e.g. unused_media.txt): ").strip()
        
    if not filepath or not os.path.exists(filepath):
        print(f"Error: File '{filepath}' does not exist.")
        sys.exit(1)
        
    with open(filepath, 'r') as f:
        keys = [line.strip() for line in f if line.strip()]
        
    if not keys:
        print("File is empty. Nothing to delete.")
        return
        
    print(f"Preparing to delete {len(keys)} files from R2 bucket '{R2_BUCKET}'.")
    confirm = input("Are you sure you want to proceed? (y/N): ").strip().lower()
    if confirm != 'y':
        print("Aborted.")
        return
        
    s3 = get_s3_client()
    deleted_count = 0
    failed_count = 0
    
    # We delete one by one to print clear progress. Could be batched but usually fine for scripts.
    for key in keys:
        try:
            print(f"Deleting {key}...", end=" ", flush=True)
            s3.delete_object(Bucket=R2_BUCKET, Key=key)
            print("OK")
            deleted_count += 1
        except Exception as e:
            print(f"FAILED ({e})")
            failed_count += 1
            
    print(f"\nDeletion complete. {deleted_count} deleted, {failed_count} failed.")

if __name__ == "__main__":
    main()
