import requests
import json
import uuid
import os

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

card_id = "0576b629-f79c-46ea-b8de-aac29ae02df5"
img_url = "https://upload.wikimedia.org/wikipedia/commons/4/4b/Fitbit_Flex_2.jpg"
USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

def process():
    # 1. Fetch current card
    resp = requests.get(f"{url_base}/rest/v1/cards?id=eq.{card_id}", headers=headers)
    card = resp.json()[0]
    
    # 2. Upload image
    i_resp = requests.get(img_url, headers={"User-Agent": USER_AGENT}, timeout=15)
    if i_resp.status_code == 200:
        storage_path = f"f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac/Tech Categories/{card_id}.jpg"
        upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
        
        requests.delete(upload_url, headers=headers)
        up_resp = requests.post(upload_url, headers={**headers, "Content-Type": "image/jpeg"}, data=i_resp.content)
        
        if up_resp.status_code in [200, 201]:
            final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
            loc_data = card['localized_data']
            loc_data['global']['image_urls'] = [final_img_url]
            
            requests.patch(f"{url_base}/rest/v1/cards?id=eq.{card_id}", headers=headers, json={"localized_data": loc_data})
            print("Successfully updated Smart healthcare image.")

if __name__ == "__main__":
    process()
