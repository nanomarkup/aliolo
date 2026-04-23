#!/usr/bin/env python3
import os
import sys
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
        sys.exit(1)
        
    return boto3.client(
        service_name="s3",
        endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=access_key_id,
        aws_secret_access_key=secret_access_key,
        region_name="auto"
    )

def main():
    s3 = get_s3_client()
    paginator = s3.get_paginator('list_objects_v2')
    pages = paginator.paginate(Bucket=R2_BUCKET)
    
    stats = {
        'images': {'count': 0, 'total_size': 0},
        'audio': {'count': 0, 'total_size': 0},
        'video': {'count': 0, 'total_size': 0},
        'other': {'count': 0, 'total_size': 0}
    }
    
    image_exts = {'.png', '.jpg', '.jpeg', '.webp', '.gif'}
    audio_exts = {'.mp3', '.wav', '.m4a', '.aac', '.ogg'}
    video_exts = {'.mp4', '.webm', '.mov'}
    
    print(f"Analyzing media in R2 bucket '{R2_BUCKET}'...")
    
    total_objects = 0
    for page in pages:
        if 'Contents' in page:
            for obj in page['Contents']:
                key = obj['Key']
                size = obj['Size']
                ext = Path(key).suffix.lower()
                
                total_objects += 1
                if ext in image_exts:
                    stats['images']['count'] += 1
                    stats['images']['total_size'] += size
                elif ext in audio_exts:
                    stats['audio']['count'] += 1
                    stats['audio']['total_size'] += size
                elif ext in video_exts:
                    stats['video']['count'] += 1
                    stats['video']['total_size'] += size
                else:
                    stats['other']['count'] += 1
                    stats['other']['total_size'] += size

    print("\n--- Media Statistics ---")
    print(f"Total Objects: {total_objects}")
    
    for category, data in stats.items():
        count = data['count']
        total_size_mb = data['total_size'] / (1024 * 1024)
        avg_size_kb = (data['total_size'] / count / 1024) if count > 0 else 0
        
        print(f"\nCategory: {category.capitalize()}")
        print(f"  Count: {count}")
        print(f"  Total Size: {total_size_mb:.2f} MB")
        print(f"  Avg Size: {avg_size_kb:.2f} KB")

if __name__ == "__main__":
    main()
