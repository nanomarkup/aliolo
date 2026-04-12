import requests
import json
import uuid
import os
import re
import time

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}"
}

# Mapping specific modern/iconic wiki titles for better images
category_updates = [
    {"name": "Wearable technology", "wiki": "Apple Watch"},
    {"name": "Smart home", "wiki": "Home automation"},
    {"name": "Personal mobility", "wiki": "Electric scooter"},
    {"name": "Immersive technology", "wiki": "Virtual reality headset"},
    {"name": "Consumer robotics", "wiki": "Robotic vacuum cleaner"},
    {"name": "Computing", "wiki": "Workstation"},
    {"name": "Digital photography", "wiki": "Mirrorless camera"},
    {"name": "Drones", "wiki": "Unmanned aerial vehicle"},
    {"name": "Smart healthcare", "wiki": "Digital health"},
    {"name": "Cloud computing", "wiki": "Datacenter"},
    {"name": "Artificial intelligence", "wiki": "Artificial intelligence"},
    {"name": "Gaming", "wiki": "Video game console"},
    {"name": "Clean energy technology", "wiki": "Solar panel"},
    {"name": "Audio technology", "wiki": "Headphones"}
]

USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

def get_best_wiki_image(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    # Try multiple ways to get a good image
    params = {
        "action": "query",
        "prop": "pageimages|images",
        "titles": title,
        "piprop": "original",
        "format": "json"
    }
    try:
        resp = requests.get(wiki_url, params=params, headers={"User-Agent": USER_AGENT}).json()
        pages = resp.get("query", {}).get("pages", {})
        image_url = None
        for pid in pages:
            if int(pid) < 0: continue
            page = pages[pid]
            # 1. Try page image
            image_url = page.get("original", {}).get("source")
            
            # 2. If not found or looks like a logo/icon, try checking other images
            if not image_url or any(x in image_url.lower() for x in ["logo", "icon", "symbol", "stub"]):
                images = page.get("images", [])
                for img in images:
                    img_title = img.get("title", "")
                    if any(ext in img_title.lower() for ext in [".jpg", ".png", ".jpeg"]):
                        # Skip logos
                        if any(x in img_title.lower() for x in ["logo", "icon", "symbol"]): continue
                        
                        # Get URL
                        ii_params = {"action": "query", "prop": "imageinfo", "titles": img_title, "iiprop": "url", "format": "json"}
                        ii_resp = requests.get(wiki_url, params=ii_params, headers={"User-Agent": USER_AGENT}).json()
                        ii_pages = ii_resp.get("query", {}).get("pages", {})
                        for iipid in ii_pages:
                            candidate = ii_pages[iipid].get("imageinfo", [{}])[0].get("url")
                            if candidate: 
                                image_url = candidate
                                break
                    if image_url: break
        return image_url
    except:
        return None

def update_images():
    # Fetch cards to match by name
    resp = requests.get(f"{url_base}/rest/v1/cards?subject_id=eq.8db933e6-8906-4e4b-86f5-7c863fe1ef01&select=id,localized_data", headers=headers)
    cards = resp.json()
    
    for update in category_updates:
        card = next((c for c in cards if c['localized_data']['global']['answer'] == update['name']), None)
        if not card: 
            print(f"Card not found for {update['name']}")
            continue
            
        print(f"Updating image for {update['name']} using Wiki: {update['wiki']}...")
        img_url = get_best_wiki_image(update['wiki'])
        
        if not img_url:
            print(f"Could not find image for {update['wiki']}")
            continue
            
        # Download and upload
        try:
            i_resp = requests.get(img_url, headers={"User-Agent": USER_AGENT}, timeout=15)
            if i_resp.status_code == 200:
                ext = "png" if "png" in img_url.lower() else "jpg"
                storage_path = f"f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac/Tech Categories/{card['id']}.{ext}"
                upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
                
                # Overwrite existing if needed (Supabase Storage allows it or we delete first)
                # For simplicity, we just POST. If it fails, we try to DELETE then POST.
                up_resp = requests.post(upload_url, headers={**headers, "Content-Type": i_resp.headers.get("Content-Type", "image/jpeg")}, data=i_resp.content)
                if up_resp.status_code not in [200, 201]:
                    requests.delete(upload_url, headers=headers)
                    up_resp = requests.post(upload_url, headers={**headers, "Content-Type": i_resp.headers.get("Content-Type", "image/jpeg")}, data=i_resp.content)
                
                if up_resp.status_code in [200, 201]:
                    final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
                    
                    # Update card localized_data global image_urls
                    loc_data = card['localized_data']
                    loc_data['global']['image_urls'] = [final_img_url]
                    
                    patch_resp = requests.patch(f"{url_base}/rest/v1/cards?id=eq.{card['id']}", headers=headers, json={"localized_data": loc_data})
                    print(f"Successfully updated {update['name']}: {patch_resp.status_code}")
                else:
                    print(f"Upload failed for {update['name']}")
            else:
                print(f"Download failed for {img_url}")
        except Exception as e:
            print(f"Error for {update['name']}: {e}")
        
        time.sleep(0.5)

if __name__ == "__main__":
    update_images()
