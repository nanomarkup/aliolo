import requests
import json

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

subject_id = "193530d9-3e12-422a-801f-a0af7799f235"
valid_planets = ['Mercury', 'Venus', 'Earth', 'Mars', 'Jupiter', 'Saturn', 'Uranus', 'Neptune', 'Ceres', 'Pluto', 'Haumea', 'Makemake', 'Eris']

def cleanup():
    resp = requests.get(f"{url_base}/rest/v1/cards?subject_id=eq.{subject_id}&select=id,localized_data", headers=headers)
    cards = resp.json()
    
    ids_to_delete = []
    for card in cards:
        ans = card.get('localized_data', {}).get('global', {}).get('answer', '')
        if ans not in valid_planets:
            ids_to_delete.append(card['id'])
            
    print(f"Found {len(ids_to_delete)} old/duplicate cards to delete.")
    
    if ids_to_delete:
        # Delete in chunks or all at once if supported. The REST API supports 'in' operator.
        id_list = ",".join(ids_to_delete)
        del_resp = requests.delete(f"{url_base}/rest/v1/cards?id=in.({id_list})", headers=headers)
        print(f"Deleted old cards: {del_resp.status_code}")

if __name__ == "__main__":
    cleanup()
