import requests
import json
import time

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

def delete_files(bucket_id, files):
    if not files:
        return 0
        
    success_count = 0
    # Supabase allows batch delete via /object/remove/{bucket}
    # We'll batch them in groups of 100 to be safe
    batch_size = 100
    for i in range(0, len(files), batch_size):
        batch = files[i:i+batch_size]
        print(f"  Deleting batch of {len(batch)} from {bucket_id}...")
        
        res = requests.delete(f"{URL}/storage/v1/object/{bucket_id}", headers=headers, json={
            "prefixes": batch
        })
        
        if res.status_code == 200:
            success_count += len(batch)
        else:
            print(f"  [!] Failed to delete batch: {res.status_code} - {res.text}")
            
        # Small sleep to prevent hammering the API
        time.sleep(0.2)
        
    return success_count

def main():
    try:
        with open("storage_audit_report.json", "r") as f:
            report = json.load(f)
    except FileNotFoundError:
        print("Error: storage_audit_report.json not found. Please run the audit script first.")
        return

    print("--- Storage Cleanup ---")
    total_deleted = 0

    for bucket_id, stats in report.items():
        unused = stats.get("unused", [])
        if not unused:
            print(f"Bucket {bucket_id}: No unused files to delete.")
            continue
            
        print(f"Bucket {bucket_id}: Deleting {len(unused)} unused files...")
        count = delete_files(bucket_id, unused)
        total_deleted += count
        print(f"Successfully deleted {count} files from {bucket_id}.")

    print(f"\nCleanup complete. Total files removed: {total_deleted}")

if __name__ == "__main__":
    main()
