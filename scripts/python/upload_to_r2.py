import os
import subprocess
import concurrent.futures

BASE_DIR = "./assets/cards"
BUCKET = "aliolo-media"
REMOTE_PREFIX = "cards"

def upload_file(local_path, r2_key):
    # Determine content type
    ext = os.path.splitext(local_path)[1].lower()
    content_type = "application/octet-stream"
    if ext in ['.jpg', '.jpeg']: content_type = "image/jpeg"
    elif ext == '.png': content_type = "image/png"
    elif ext == '.webp': content_type = "image/webp"

    cmd = [
        "npx", "wrangler", "r2", "object", "put",
        f"{BUCKET}/{r2_key}",
        f"--file={local_path}",
        f"--content-type={content_type}",
        "--remote"
    ]
    
    # Run silently
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return False, r2_key
    return True, r2_key

def main():
    files_to_upload = []
    for root, dirs, files in os.walk(BASE_DIR):
        for file in files:
            local_path = os.path.join(root, file)
            rel_path = os.path.relpath(local_path, BASE_DIR)
            r2_key = f"{REMOTE_PREFIX}/{rel_path}"
            files_to_upload.append((local_path, r2_key))

    total = len(files_to_upload)
    print(f"Starting upload of {total} files using 20 workers...")
    
    success = 0
    failed = []
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=20) as executor:
        futures = [executor.submit(upload_file, lp, rk) for lp, rk in files_to_upload]
        for i, future in enumerate(concurrent.futures.as_completed(futures)):
            ok, key = future.result()
            if ok:
                success += 1
            else:
                failed.append(key)
            
            if (i + 1) % 50 == 0:
                print(f"Progress: {i+1}/{total}...")

    print(f"\nUpload finished!")
    print(f"Success: {success}")
    print(f"Failed: {len(failed)}")
    if failed:
        print("First 5 failures:", failed[:5])

if __name__ == "__main__":
    main()
