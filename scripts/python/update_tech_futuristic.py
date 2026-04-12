import requests
import json
import os
import time

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

# Map card global answer to new futuristic/modern image URL
futuristic_updates = [
    {"name": "Computing", "url": "https://upload.wikimedia.org/wikipedia/commons/d/d7/Foldable_Smartphones.jpg"},
    {"name": "Gaming", "url": "https://upload.wikimedia.org/wikipedia/commons/5/5e/Steam_Deck_with_dock.jpg"},
    {"name": "Smart healthcare", "url": "https://upload.wikimedia.org/wikipedia/commons/4/49/Operation_Room_Robotic_Surgery.jpg"},
    {"name": "Personal mobility", "url": "https://upload.wikimedia.org/wikipedia/commons/b/b2/Paris_without_cars_2015_Unicycles.jpg"}
]

def process():
    resp = requests.get(f"{url_base}/rest/v1/cards?subject_id=eq.8db933e6-8906-4e4b-86f5-7c863fe1ef01&select=id,localized_data", headers=headers)
    cards = resp.json()
    
    for up in futuristic_updates:
        card = next((c for c in cards if c['localized_data']['global']['answer'] == up['name']), None)
        if not card: continue
        
        print(f"Updating {up['name']} with futuristic image...")
        img_url = up['url']
        try:
            i_resp = requests.get(img_url, headers={"User-Agent": USER_AGENT}, timeout=15)
            if i_resp.status_code == 200:
                ext = "png" if "png" in img_url.lower() else "jpg"
                storage_path = f"f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac/Tech Categories/{card['id']}.{ext}"
                upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
                
                requests.delete(upload_url, headers=headers)
                up_resp = requests.post(upload_url, headers={**headers, "Content-Type": "image/jpeg"}, data=i_resp.content)
                
                if up_resp.status_code in [200, 201]:
                    final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
                    loc_data = card['localized_data']
                    loc_data['global']['image_urls'] = [final_img_url]
                    requests.patch(f"{url_base}/rest/v1/cards?id=eq.{card['id']}", headers=headers, json={"localized_data": loc_data})
                    print(f"Successfully updated {up['name']}")
        except Exception as e:
            print(f"Error for {up['name']}: {e}")
        
        time.sleep(0.5)

if __name__ == "__main__":
    process()
