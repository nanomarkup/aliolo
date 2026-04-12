import sys
import requests

URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {"apikey": KEY, "Authorization": "Bearer " + KEY, "Content-Type": "application/json"}

print("Fetching Botany subject...")
res = requests.get(f"{URL}/rest/v1/subjects?select=id,localized_data", headers=headers)
subjects = res.json()

subject_id = None
for s in subjects:
    glob = s.get("localized_data", {}).get("global", {})
    if glob.get("name") == "Botany":
        subject_id = s["id"]
        break

if not subject_id:
    print("Could not find Botany subject.")
    sys.exit(0)

print(f"Found Botany subject ID: {subject_id}")

print("Deleting cards...")
del_cards_res = requests.delete(f"{URL}/rest/v1/cards?subject_id=eq.{subject_id}", headers=headers)
if del_cards_res.status_code in [200, 204]:
    print("Successfully deleted cards.")
else:
    print(f"Failed to delete cards: {del_cards_res.status_code} - {del_cards_res.text}")

print("Deleting subject...")
del_subject_res = requests.delete(f"{URL}/rest/v1/subjects?id=eq.{subject_id}", headers=headers)
if del_subject_res.status_code in [200, 204]:
    print("Successfully deleted subject.")
else:
    print(f"Failed to delete subject: {del_subject_res.status_code} - {del_subject_res.text}")
