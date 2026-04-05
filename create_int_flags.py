import requests
from bs4 import BeautifulSoup
import json
import time
import os
import uuid

# Configuration
SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
OWNER_ID = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
PILLAR_ID = 7
BUCKET_NAME = "card_images"
WIKI_URL = "https://en.wikipedia.org/wiki/Flags_of_international_organizations"
USER_AGENT = "AlioloContentBot/1.0 (vitaliinoga@aliolo.com)"
HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}
WIKI_HEADERS = {"User-Agent": USER_AGENT}

LANGS = "en,id,bg,cs,da,de,et,es,fr,ga,hr,it,lv,lt,hu,mt,nl,pl,pt,ro,sk,sl,fi,sv,tl,vi,tr,el,uk,ar,hi,zh,ja,ko".split(",")

def get_wikidata_qid(name):
    url = "https://www.wikidata.org/w/api.php"
    params = {
        "action": "wbsearchentities",
        "format": "json",
        "search": name,
        "language": "en",
        "type": "item"
    }
    try:
        res = requests.get(url, params=params, headers=WIKI_HEADERS)
        if res.status_code == 200:
            data = res.json()
            if data.get("search"):
                return data["search"][0]["id"]
    except Exception as e:
        print(f"Error searching {name}: {e}")
    return None

def get_labels(qid):
    if not qid:
        return {}
    url = "https://www.wikidata.org/w/api.php"
    params = {
        "action": "wbgetentities",
        "format": "json",
        "ids": qid,
        "props": "labels",
        "languages": "|".join(LANGS)
    }
    try:
        res = requests.get(url, params=params, headers=WIKI_HEADERS)
        if res.status_code == 200:
            data = res.json()
            labels = {}
            if data.get("entities") and qid in data["entities"]:
                entity_labels = data["entities"][qid].get("labels", {})
                for lang in LANGS:
                    if lang in entity_labels:
                        labels[lang] = entity_labels[lang]["value"]
                    elif "en" in entity_labels:
                        labels[lang] = entity_labels["en"]["value"]
                return labels
    except Exception as e:
        print(f"Error getting labels for {qid}: {e}")
    return {}

def scrape_org_flags():
    response = requests.get(WIKI_URL, headers=WIKI_HEADERS)
    if response.status_code != 200:
        print(f"Error {response.status_code}: {response.text[:200]}")
        return []
    soup = BeautifulSoup(response.content, 'html.parser')
    orgs = []
    
    # Wikipedia page has multiple galleries
    galleries = soup.find_all('li', {'class': 'gallerybox'})
    print(f"Found {len(galleries)} gallery boxes.")
    for box in galleries:
        img = box.find('img')
        if not img:
            continue
            
        gallery_text = box.find('div', {'class': 'gallerytext'})
        if not gallery_text:
            continue
            
        # Try to find the organization name. 
        # Usually it's "Flag of the [Organization Name]" or "Flag of [Organization Name]"
        # We can look for the last <a> tag that doesn't contain "Flag" or just clean up the text.
        links = gallery_text.find_all('a')
        org_name = ""
        for link in links:
            text = link.get_text(strip=True)
            if text.lower() != "flag":
                org_name = text
                break
        
        if not org_name:
            # Fallback to full text cleanup
            full_text = gallery_text.get_text(strip=True)
            org_name = full_text.replace("Flag of the ", "").replace("Flag of ", "").replace("Flag", "").strip()
            # If it starts with "of ", remove it
            if org_name.startswith("of "):
                org_name = org_name[3:].strip()

        if not org_name or len(org_name) < 2:
            continue

        src = img.get('src')
        if img.get('srcset'):
            # Get the largest image from srcset
            srcset_parts = img.get('srcset').split(',')
            largest_part = srcset_parts[-1].strip().split(' ')[0]
            src = largest_part
        
        if src.startswith('//'):
            src = 'https:' + src
        
        orgs.append({
            'name': org_name,
            'flag_url': src
        })
    
    # Also look for tables just in case
    tables = soup.find_all('table', {'class': 'wikitable'})
    print(f"Found {len(tables)} tables.")
    for table in tables:
        rows = table.find_all('tr')
        for row in rows:
            cells = row.find_all(['td', 'th'])
            if len(cells) < 2:
                continue
            
            img_cell = cells[0]
            name_cell = cells[1]
            
            img = img_cell.find('img')
            if not img:
                continue
            
            a = name_cell.find('a')
            if not a:
                continue
            
            org_name = a.get_text(strip=True)
            if not org_name or len(org_name) < 2:
                continue
            
            if org_name.lower() in ["flag", "organization", "description", "union"]:
                continue

            src = img.get('src')
            if img.get('srcset'):
                srcset_parts = img.get('srcset').split(',')
                largest_part = srcset_parts[-1].strip().split(' ')[0]
                src = largest_part
            
            if src.startswith('//'):
                src = 'https:' + src
            
            orgs.append({
                'name': org_name,
                'flag_url': src
            })
            
    return orgs

def upload_image(image_url, remote_path):
    print(f"Uploading image {image_url} to {remote_path}...")
    try:
        resp = requests.get(image_url, headers=WIKI_HEADERS)
        if resp.status_code != 200:
            print(f"Failed to download image: {resp.status_code}")
            return None
        
        content_type = resp.headers.get('Content-Type', 'image/png')
        
        upload_url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET_NAME}/{remote_path}"
        headers = {
            "apikey": SERVICE_ROLE_KEY,
            "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
            "Content-Type": content_type
        }
        
        up_resp = requests.post(upload_url, data=resp.content, headers=headers)
        if up_resp.status_code == 200:
            return f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{remote_path}"
        else:
            print(f"Failed to upload image: {up_resp.status_code} - {up_resp.text}")
            # Try PUT if POST failed (might already exist)
            up_resp = requests.put(upload_url, data=resp.content, headers=headers)
            if up_resp.status_code == 200:
                return f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{remote_path}"
            return None
    except Exception as e:
        print(f"Error uploading image: {e}")
    return None

def create_subject():
    print("Creating Subject...")
    # Translate "Flags of International Organizations"
    # and "Identify the flags of global and regional international organizations."
    
    # Since I don't have a reliable auto-translation for sentences easily here, 
    # and Wikidata is for entities, I'll use Wikidata for the name if possible, 
    # or just use a very simple fallback if it fails.
    # Actually, the subject name might be in Wikidata!
    
    qid = get_wikidata_qid("Flags of International Organizations")
    name_translations = get_labels(qid)
    if not name_translations:
        name_translations = {lang: "Flags of International Organizations" for lang in LANGS}
    
    # Description translation is harder. I'll just use English for all or try to find it.
    # For now, English description for all.
    desc = "Identify the flags of global and regional international organizations."
    
    localized_data = {}
    for lang in LANGS:
        localized_data[lang] = {
            "name": name_translations.get(lang, "Flags of International Organizations"),
            "description": desc
        }
    localized_data["global"] = {
        "name": "Flags of International Organizations",
        "description": desc
    }
    
    payload = {
        "pillar_id": PILLAR_ID,
        "owner_id": OWNER_ID,
        "localized_data": localized_data,
        "is_public": True,
        "age_group": "15_plus"
    }
    
    res = requests.post(f"{SUPABASE_URL}/rest/v1/subjects", headers=HEADERS, json=payload)
    if res.status_code == 201:
        data = res.json()
        subject_id = data[0]["id"]
        print(f"Created Subject with ID: {subject_id}")
        return subject_id
    else:
        print(f"Failed to create subject: {res.status_code} - {res.text}")
        return None

def main():
    # 1. Scrape data
    print("Scraping Wikipedia...")
    orgs = scrape_org_flags()
    print(f"Scraped {len(orgs)} organizations.")
    
    # Deduplicate
    unique_orgs = {o['name']: o for o in orgs}.values()
    print(f"Unique organizations: {len(unique_orgs)}")
    
    # 2. Create Subject
    subject_id = create_subject()
    if not subject_id:
        return
    
    # 3. Create Cards
    subject_folder = "Flags of International Organizations"
    for org in unique_orgs:
        name = org['name']
        print(f"\nProcessing {name}...")
        
        # Get translations
        qid = get_wikidata_qid(name)
        labels = get_labels(qid)
        if not labels:
            labels = {lang: name for lang in LANGS}
        
        # Download and Upload Image
        card_id = str(uuid.uuid4())
        ext = org['flag_url'].split('.')[-1].split('?')[0].lower()
        if ext not in ['png', 'jpg', 'jpeg', 'svg', 'webp']:
            ext = 'png'
        
        remote_path = f"{OWNER_ID}/{subject_folder}/{card_id}.{ext}"
        image_url = upload_image(org['flag_url'], remote_path)
        
        if not image_url:
            print(f"Skipping {name} due to image upload failure.")
            continue
            
        # Create Card localized_data
        card_localized_data = {}
        for lang in LANGS:
            card_localized_data[lang] = {
                "answer": labels.get(lang, name),
                "prompt": "What is this?",
                "audio_url": None
            }
        card_localized_data["global"] = {
            "answer": name,
            "prompt": "What is this?",
            "audio_url": None,
            "video_url": "",
            "image_urls": [image_url]
        }
        
        card_payload = {
            "subject_id": subject_id,
            "owner_id": OWNER_ID,
            "localized_data": card_localized_data,
            "test_mode": "image_to_text",
            "is_public": True
        }
        
        res = requests.post(f"{SUPABASE_URL}/rest/v1/cards", headers=HEADERS, json=card_payload)
        if res.status_code == 201:
            print(f"Created Card for {name}")
        else:
            print(f"Failed to create card for {name}: {res.status_code} - {res.text}")
            
        time.sleep(0.5) # Avoid hitting APIs too hard

if __name__ == "__main__":
    main()
