import urllib.request
import json
import ssl

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
USER_ID = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
PILLAR_ID = 8

context = ssl._create_unverified_context()

def check_localized_data():
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }
    url = f"{SUPABASE_URL}/rest/v1/subjects?owner_id=eq.{USER_ID}&pillar_id=eq.{PILLAR_ID}&select=id,localized_data"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, context=context) as response:
        subjects = json.loads(response.read())

    from alphabet_map import ALPHABET_MAP
    all_langs = sorted(ALPHABET_MAP.keys())
    
    print(f"Target languages: {len(all_langs)}")
    
    for s in subjects:
        loc_data = s['localized_data']
        name = loc_data.get('global', {}).get('name', 'Unknown')
        missing_langs = [lang for lang in all_langs if lang not in loc_data]
        if missing_langs:
            print(f"Subject '{name}' (ID: {s['id']}) is missing {len(missing_langs)} languages.")
            # print(f"  Missing: {missing_langs}")
        else:
            print(f"Subject '{name}' is COMPLETE ({len(loc_data)} entries).")

if __name__ == "__main__":
    check_localized_data()
