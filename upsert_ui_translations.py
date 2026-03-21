import urllib.request
import json
import ssl
import os

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"

lang_dir = "assets/lang"
data_to_upsert = []

for filename in os.listdir(lang_dir):
    if filename.endswith(".json"):
        lang_code = filename.replace(".json", "")
        with open(os.path.join(lang_dir, filename), 'r') as f:
            translations = json.load(f)
            for key, value in translations.items():
                data_to_upsert.append({
                    "key": key,
                    "lang": lang_code,
                    "value": value
                })

print(f"Syncing {len(data_to_upsert)} translation entries to Supabase...")

url = f"{SUPABASE_URL}/rest/v1/ui_translations"
headers = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

context = ssl._create_unverified_context()

# Supabase REST API has limits on request size. We'll chunk the data if needed.
CHUNK_SIZE = 1000
for i in range(0, len(data_to_upsert), CHUNK_SIZE):
    chunk = data_to_upsert[i:i + CHUNK_SIZE]
    req = urllib.request.Request(url, headers=headers, data=json.dumps(chunk).encode("utf-8"), method="POST")
    try:
        with urllib.request.urlopen(req, context=context) as response:
            print(f"Chunk {i // CHUNK_SIZE + 1} Status: {response.status}")
    except urllib.error.HTTPError as e:
        print(f"HTTP Error on chunk {i // CHUNK_SIZE + 1}: {e.code} {e.reason}")
        print(e.read().decode())
    except Exception as e:
        print(f"Error on chunk {i // CHUNK_SIZE + 1}: {e}")

print("Synchronization complete.")
