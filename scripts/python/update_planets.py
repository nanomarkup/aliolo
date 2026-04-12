import requests
import json
import uuid
import os
import time
import re

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

subject_id = "193530d9-3e12-422a-801f-a0af7799f235"
owner_id = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']
USER_AGENT = "AlioloBot/1.0 (https://aliolo.com; hello@aliolo.com)"

# 1. Update Subject
subject_translations = {
    'en': {'name': 'Planets of the Solar System', 'desc': 'Explore the 8 planets and 5 dwarf planets that make up our cosmic neighborhood.'},
    'ar': {'name': 'كواكب النظام الشمسي', 'desc': 'اكتشف الكواكب الثمانية والكواكب القزمة الخمسة التي تشكل جوارنا الكوني.'},
    'bg': {'name': 'Планети от Слънчевата система', 'desc': 'Разгледайте 8-те планети и 5-те планети джуджета, които съставляват нашия космически квартал.'},
    'cs': {'name': 'Planety sluneční soustavy', 'desc': 'Prozkoumejte 8 planet a 5 trpasličích planet, které tvoří naše vesmírné sousedství.'},
    'da': {'name': 'Planeter i solsystemet', 'desc': 'Udforsk de 8 planeter og 5 dværgplaneter, der udgør vores kosmiske nabolag.'},
    'de': {'name': 'Planeten des Sonnensystems', 'desc': 'Entdecken Sie die 8 Planeten und 5 Zwergplaneten, die unsere kosmische Nachbarschaft bilden.'},
    'el': {'name': 'Πλανήτες του Ηλιακού Συστήματος', 'desc': 'Εξερευνήστε τους 8 πλανήτες και τους 5 πλανήτες νάνους που αποτελούν την κοσμική μας γειτονιά.'},
    'es': {'name': 'Planetas del Sistema Solar', 'desc': 'Explora los 8 planetas y los 5 planetas enanos que conforman nuestro vecindario cósmico.'},
    'et': {'name': 'Päikesesüsteemi planeedid', 'desc': 'Avastage 8 planeeti ja 5 kääbusplaneeti, mis moodustavad meie kosmilise naabruskonna.'},
    'fi': {'name': 'Aurinkokunnan planeetat', 'desc': 'Tutustu 8 planeettaan ja 5 kääpiöplaneettaan, jotka muodostavat kosmisen naapurustomme.'},
    'fr': {'name': 'Planètes du système solaire', 'desc': 'Explorez les 8 planètes et les 5 planètes naines qui composent notre voisinage cosmique.'},
    'ga': {'name': 'Pláinéid an Chórais Ghréine', 'desc': 'Déan iniúchadh ar na 8 bpláinéad agus na 5 abhacphláinéad atá inár gcomharsanacht chosmach.'},
    'hi': {'name': 'सौर मंडल के ग्रह', 'desc': 'हमारे ब्रह्मांडीय पड़ोस को बनाने वाले 8 ग्रहों और 5 बौने ग्रहों का अन्वेषण करें।'},
    'hr': {'name': 'Planeti Sunčevog sustava', 'desc': 'Istražite 8 planeta i 5 patuljastih planeta koji čine naše kozmičko susjedstvo.'},
    'hu': {'name': 'A Naprendszer bolygói', 'desc': 'Fedezze fel a 8 bolygót és az 5 törpebolygót, amelyek kozmikus szomszédságunkat alkotják.'},
    'id': {'name': 'Planet Tata Surya', 'desc': 'Jelajahi 8 planet dan 5 planet kerdil yang membentuk lingkungan kosmik kita.'},
    'it': {'name': 'Pianeti del Sistema Solare', 'desc': 'Esplora gli 8 pianeti e i 5 pianeti nani che compongono il nostro vicinato cosmico.'},
    'ja': {'name': '太陽系の惑星', 'desc': '私たちの宇宙の近所を構成する8つの惑星と5つの準惑星を探索しましょう。'},
    'ko': {'name': '태양계의 행성', 'desc': '우리 우주 이웃을 구성하는 8개의 행성과 5개의 왜소행성을 탐험해 보세요.'},
    'lt': {'name': 'Saulės sistemos planetos', 'desc': 'Tyrinėkite 8 planetas ir 5 nykštukines planetas, sudarančias mūsų kosminę kaimynystę.'},
    'lv': {'name': 'Saules sistēmas planētas', 'desc': 'Izpētiet 8 planētas un 5 pundurplanētas, kas veido mūsu kosmisko apkaimi.'},
    'mt': {'name': 'Pjaneti tas-Sistema Solari', 'desc': 'Esplora t-8 pjaneti u l-5 pjaneti nani li jiffurmaw il-viċinat kożmiku tagħna.'},
    'nl': {'name': 'Planeten van het zonnestelsel', 'desc': 'Verken de 8 planeten en 5 dwergplaneten die onze kosmische buurt vormen.'},
    'pl': {'name': 'Planety Układu Słonecznego', 'desc': 'Odkryj 8 planet i 5 planet karłowatych, które tworzą nasze kosmiczne sąsiedztwo.'},
    'pt': {'name': 'Planetas do Sistema Solar', 'desc': 'Explore os 8 planetas e os 5 planetas anões que compõem nossa vizinhança cósmica.'},
    'ro': {'name': 'Planetele Sistemului Solar', 'desc': 'Explorați cele 8 planete și 5 planete pitice care alcătuiesc vecinătatea noastră cosmică.'},
    'sk': {'name': 'Planéty slnečnej sústavy', 'desc': 'Preskúmajte 8 planét a 5 trpasličích planét, ktoré tvoria naše vesmírne susedstvo.'},
    'sl': {'name': 'Planeti Osončja', 'desc': 'Raziščite 8 planetov in 5 pritlikavih planetov, ki sestavljajo našo kozmično soseščino.'},
    'sv': {'name': 'Solsystemets planeter', 'desc': 'Utforska de 8 planeterna och 5 dvärgplaneterna som utgör vårt kosmiska grannskap.'},
    'tl': {'name': 'Mga Planeta ng Solar System', 'desc': 'Galugarin ang 8 planeta at 5 dwarf na planeta na bumubuo sa ating cosmic na kapitbahayan.'},
    'tr': {'name': 'Güneş Sistemi Gezegenleri', 'desc': 'Kozmik mahallemizi oluşturan 8 gezegeni ve 5 cüce gezegeni keşfedin.'},
    'uk': {'name': 'Планети Сонячної системи', 'desc': 'Досліджуйте 8 планет і 5 карликових планет, які складають наше космічне сусідство.'},
    'vi': {'name': 'Các hành tinh trong Hệ Mặt trời', 'desc': 'Khám phá 8 hành tinh và 5 hành tinh lùn tạo nên vùng lân cận vũ trụ của chúng ta.'},
    'zh': {'name': '太阳系行星', 'desc': '探索组成我们宇宙邻居的 8 颗行星和 5 颗矮行星。'}
}

def update_subject():
    loc_data = {}
    for lang in langs:
        t = subject_translations.get(lang, subject_translations['en'])
        loc_data[lang] = {
            "name": t['name'],
            "description": t['desc']
        }
    
    loc_data["global"] = {
        "name": subject_translations['en']['name'],
        "description": subject_translations['en']['desc']
    }
    
    payload = {
        "localized_data": loc_data
    }
    
    resp = requests.patch(f"{url_base}/rest/v1/subjects?id=eq.{subject_id}", headers=headers, json=payload)
    if resp.status_code >= 400:
        print(f"Failed to update subject: {resp.text}")
    else:
        print("Successfully updated subject name and description.")

# 2. Add Cards
planets = [
    # 8 Planets
    {"name": "Mercury", "wiki": "Mercury (planet)"},
    {"name": "Venus", "wiki": "Venus"},
    {"name": "Earth", "wiki": "Earth"},
    {"name": "Mars", "wiki": "Mars"},
    {"name": "Jupiter", "wiki": "Jupiter"},
    {"name": "Saturn", "wiki": "Saturn"},
    {"name": "Uranus", "wiki": "Uranus"},
    {"name": "Neptune", "wiki": "Neptune"},
    # 5 Dwarf Planets
    {"name": "Ceres", "wiki": "Ceres (dwarf planet)"},
    {"name": "Pluto", "wiki": "Pluto"},
    {"name": "Haumea", "wiki": "Haumea"},
    {"name": "Makemake", "wiki": "Makemake"},
    {"name": "Eris", "wiki": "Eris (dwarf planet)"}
]

def get_wikipedia_info(title):
    wiki_url = "https://en.wikipedia.org/w/api.php"
    params = {
        "action": "query",
        "prop": "langlinks|pageimages",
        "titles": title,
        "lllimit": 500,
        "piprop": "original",
        "format": "json"
    }
    try:
        resp = requests.get(wiki_url, params=params, headers={"User-Agent": USER_AGENT}).json()
        pages = resp.get("query", {}).get("pages", {})
        translations = { 'en': title.split(' (')[0] } # Fallback to base name without disambiguation
        image_url = None
        for pid in pages:
            if int(pid) < 0: continue
            page = pages[pid]
            image_url = page.get("original", {}).get("source")
            links = page.get("langlinks", [])
            for link in links:
                lang = link.get("lang")
                val = link.get("*")
                if lang in langs: translations[lang] = val
                elif lang == 'fil' and 'tl' in langs: translations['tl'] = val
                elif lang == 'zh-hans' and 'zh' in langs: translations['zh'] = val
        return translations, image_url
    except:
        return { 'en': title.split(' (')[0] }, None

def process_cards():
    cards_to_insert = []
    
    for i, body in enumerate(planets):
        name = body['name']
        wiki_title = body['wiki']
        level = i + 1 # Levels 1 to 13
        
        print(f"Processing {name} (Level {level})...")
        translations, img_url = get_wikipedia_info(wiki_title)
        
        card_id = str(uuid.uuid4())
        final_img_url = ""
        
        if img_url:
            try:
                i_resp = requests.get(img_url, headers={"User-Agent": USER_AGENT}, timeout=10)
                if i_resp.status_code == 200:
                    ext = "jpg"
                    if "png" in img_url.lower(): ext = "png"
                    
                    storage_path = f"{owner_id}/Planets/{card_id}.{ext}"
                    upload_url = f"{url_base}/storage/v1/object/card_images/{storage_path}"
                    
                    up_resp = requests.post(upload_url, headers={**headers, "Content-Type": i_resp.headers.get("Content-Type", "image/jpeg")}, data=i_resp.content)
                    if up_resp.status_code in [200, 201]:
                        final_img_url = f"{url_base}/storage/v1/object/public/card_images/{storage_path}"
            except Exception as e:
                print(f"Error downloading/uploading image for {name}: {e}")

        loc_data = {}
        for lang in langs:
            # Clean up translation if it has disambiguation brackets
            t_name = translations.get(lang, name)
            t_name = re.sub(r'\s*\(.*?\)', '', t_name).strip()
            loc_data[lang] = {"answer": t_name, "prompt": "", "audio_url": None}
            
        loc_data["global"] = {
            "answer": name, "prompt": "", "audio_url": None, "video_url": "", 
            "image_urls": [final_img_url] if final_img_url else []
        }
        
        cards_to_insert.append({
            "id": card_id,
            "subject_id": subject_id,
            "level": level,
            "owner_id": owner_id,
            "is_public": True,
            "test_mode": "image_to_text",
            "localized_data": loc_data
        })
        time.sleep(0.1)

    if cards_to_insert:
        ins_resp = requests.post(f"{url_base}/rest/v1/cards", headers={**headers, "Content-Type": "application/json", "Prefer": "return=minimal"}, json=cards_to_insert)
        print(f"Inserted {len(cards_to_insert)} cards: {ins_resp.status_code}")

if __name__ == "__main__":
    update_subject()
    process_cards()
