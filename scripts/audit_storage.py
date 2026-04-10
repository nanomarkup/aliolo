import requests
import json

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

def list_all_files(bucket_id, path=""):
    files = []
    # Supabase Storage list objects
    res = requests.post(f"{URL}/storage/v1/object/list/{bucket_id}", headers=headers, json={
        "prefix": path,
        "limit": 1000,
        "offset": 0,
        "sortBy": {"column": "name", "order": "asc"}
    })
    
    if res.status_code != 200:
        print(f"Error listing files in {bucket_id}/{path}: {res.text}")
        return []
        
    items = res.json()
    for item in items:
        full_name = f"{path}/{item['name']}" if path else item['name']
        if item.get('id') is None: # It's a folder
            files.extend(list_all_files(bucket_id, full_name))
        else:
            files.append(full_name)
    return files

print("--- Storage Audit ---")

# 1. Fetch DB references
print("Fetching database references...")

# Profiles avatars
res = requests.get(f"{URL}/rest/v1/profiles?select=avatar_url", headers=headers)
avatar_urls = [p['avatar_url'] for p in res.json() if p.get('avatar_url')]

# Card media
res = requests.get(f"{URL}/rest/v1/cards?select=localized_data", headers=headers)
card_data = res.json()
referenced_media = set()

for c in card_data:
    loc = c.get('localized_data') or {}
    for lang in loc.values():
        if isinstance(lang, dict):
            # image_urls
            imgs = lang.get('image_urls')
            if isinstance(imgs, list):
                for img in imgs: referenced_media.add(img)
            # audio_url
            aud = lang.get('audio_url')
            if aud: referenced_media.add(aud)
            # video_url
            vid = lang.get('video_url')
            if vid: referenced_media.add(vid)

# Feedback attachments
res = requests.get(f"{URL}/rest/v1/feedbacks?select=attachment_urls", headers=headers)
fb_urls = []
for f in res.json():
    if f.get('attachment_urls'): fb_urls.extend(f['attachment_urls'])

res = requests.get(f"{URL}/rest/v1/feedback_replies?select=attachment_urls", headers=headers)
for f in res.json():
    if f.get('attachment_urls'): fb_urls.extend(f['attachment_urls'])

all_db_urls = set(avatar_urls) | referenced_media | set(fb_urls)
print(f"Found {len(all_db_urls)} unique file references in database.")

# 2. Audit Buckets
buckets = ["card_images", "avatars", "card_audio", "card_videos", "feedback_attachments"]
report = {}

for b in buckets:
    print(f"Auditing bucket: {b}...")
    files = list_all_files(b)
    report[b] = {
        "total_files": len(files),
        "unused": []
    }
    
    for f in files:
        # Check if file path is part of any URL in DB
        # URLs typically look like: .../storage/v1/object/public/bucket_id/path/to/file.jpg
        found = False
        target_suffix = f"{b}/{f}"
        for db_url in all_db_urls:
            if target_suffix in db_url:
                found = True
                break
        
        if not found:
            report[b]["unused"].append(f)

# 3. Print Summary
print("\n--- Audit Results ---")
for b, stats in report.items():
    print(f"Bucket: {b}")
    print(f"  Total Files: {stats['total_files']}")
    print(f"  Unused Files: {len(stats['unused'])}")
    if stats['unused']:
        # Show first 5 unused
        for uf in stats['unused'][:5]:
            print(f"    - {uf}")
        if len(stats['unused']) > 5:
            print(f"    ... and {len(stats['unused']) - 5} more")

# Save detailed report
with open("storage_audit_report.json", "w") as f:
    json.dump(report, f, indent=2)
print("\nDetailed report saved to storage_audit_report.json")
