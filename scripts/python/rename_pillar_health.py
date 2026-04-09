import requests
import json

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}",
    "Content-Type": "application/json",
    "Prefer": "return=representation"
}

# New translations for "Health" and its description
# "Explore the human body, anatomy, nutrition, and tips for staying healthy."
new_translations = {
    'en': {'name': 'Health', 'desc': 'Explore the human body, anatomy, nutrition, and tips for staying healthy.'},
    'ar': {'name': 'الصحة', 'desc': 'استكشف جسم الإنسان والتشريح والتغذية ونصائح للحفاظ على صحتك.'},
    'bg': {'name': 'Здраве', 'desc': 'Опознайте човешкото тяло, анатомията, храненето и съвети за здравословен начин на живот.'},
    'cs': {'name': 'Zdraví', 'desc': 'Objevujte lidské tělo, anatomii, výživu a tipy pro udržení zdraví.'},
    'da': {'name': 'Sundhed', 'desc': 'Udforsk menneskekroppen, anatomi, ernæring og tips til at forblive sund.'},
    'de': {'name': 'Gesundheit', 'desc': 'Erforschen Sie den menschlichen Körper, Anatomie, Ernährung und Tipps für ein gesundes Leben.'},
    'el': {'name': 'Υγεία', 'desc': 'Εξερευνήστε το ανθρώπινο σώμα, την ανατομία, τη διατροφή και συμβουλές για να παραμείνετε υγιείς.'},
    'es': {'name': 'Salud', 'desc': 'Explora el cuerpo humano, la anatomía, la nutrición y consejos para mantenerte saludable.'},
    'et': {'name': 'Tervis', 'desc': 'Avasta inimese keha, anatoomiat, toitumist ja nõuandeid tervislikuks eluviisiks.'},
    'fi': {'name': 'Terveys', 'desc': 'Tutustu ihmiskehoon, anatomiaan, ravitsemukseen ja vinkkeihin terveyden ylläpitämiseksi.'},
    'fr': {'name': 'Santé', 'desc': 'Découvrez le corps humain, l\'anatomie, la nutrition et des conseils pour rester en bonne santé.'},
    'ga': {'name': 'Sláinte', 'desc': 'Déan iniúchadh ar chorp an duine, anatamaíocht, cothú, agus leideanna maidir le fanacht sláintiúil.'},
    'hi': {'name': 'स्वास्थ्य', 'desc': 'मानव शरीर, शरीर रचना विज्ञान, पोषण और स्वस्थ रहने के सुझावों का अन्वेषण करें।'},
    'hr': {'name': 'Zdravlje', 'desc': 'Istražite ljudsko tijelo, anatomiju, prehranu i savjete za očuvanje zdravlja.'},
    'hu': {'name': 'Egészség', 'desc': 'Ismerje meg az emberi testet, az anatómiát, a táplálkozást és az egészségmegőrzési tippeket.'},
    'id': {'name': 'Kesehatan', 'desc': 'Jelajahi tubuh manusia, anatomi, nutrisi, dan tips untuk tetap sehat.'},
    'it': {'name': 'Salute', 'desc': 'Esplora il corpo umano, l\'anatomia, la nutrizione e i consigli per mantenersi in salute.'},
    'ja': {'name': '健康', 'desc': '人体、解剖学、栄養学、そして健康を維持するためのヒントについて学びましょう。'},
    'ko': {'name': '건강', 'desc': '인체, 해부학, 영양 및 건강 유지 요령에 대해 알아보세요.'},
    'lt': {'name': 'Sveikata', 'desc': 'Susipažinkite su žmogaus kūnu, anatomija, mityba ir patarimais, kaip išlikti sveikiems.'},
    'lv': {'name': 'Veselība', 'desc': 'Iepazīstiet cilvēka ķermeni, anatomiju, uzturu un padomus veselības saglabāšanai.'},
    'mt': {'name': 'Saħħa', 'desc': 'Esplora l-ġisem tal-bniedem, l-anatomija, in-nutrizzjoni, u suġġerimenti biex tibqa\' b\'saħħtu.'},
    'nl': {'name': 'Gezondheid', 'desc': 'Ontdek het menselijk lichaam, anatomie, voeding en tips om gezond te blijven.'},
    'pl': {'name': 'Zdrowie', 'desc': 'Poznaj ludzkie ciało, anatomię, żywienie i wskazówki dotyczące zdrowego trybu życia.'},
    'pt': {'name': 'Saúde', 'desc': 'Explore o corpo humano, anatomia, nutrição e dicas para se manter saudável.'},
    'ro': {'name': 'Sănătate', 'desc': 'Explorează corpul uman, anatomia, nutriția și sfaturi pentru a rămâne sănătos.'},
    'sk': {'name': 'Zdravie', 'desc': 'Objavujte ľudské telo, anatómiu, výživu a tipy na udržanie zdravia.'},
    'sl': {'name': 'Zdravje', 'desc': 'Spoznajte človeško telo, anatomijo, prehrano in nasvete za ohranjanje zdravja.'},
    'sv': {'name': 'Hälsa', 'desc': 'Utforska människokroppen, anatomi, näringslära och tips för att hålla dig frisk.'},
    'tl': {'name': 'Kalusugan', 'desc': 'Tuklasin ang katawan ng tao, anatomiya, nutrisyon, at mga tip para sa pananatiling malusog.'},
    'tr': {'name': 'Sağlık', 'desc': 'İnsan vücudunu, anatomiyi, beslenmeyi ve sağlıklı kalma ipuçlarını keşfedin.'},
    'uk': {'name': 'Здоров\'я', 'desc': 'Дізнайтеся про людське тіло, анатомію, харчування та поради щодо збереження здоров\'я.'},
    'vi': {'name': 'Sức khỏe', 'desc': 'Khám phá cơ thể con người, giải phẫu, dinh dưỡng và các lời khuyên để sống khỏe mạnh.'},
    'zh': {'name': '健康', 'desc': '探索人体、解剖学、营养以及保持健康的技巧。'}
}

def update_pillar():
    # Fetch current pillar 2
    resp = requests.get(f"{url_base}/rest/v1/pillars?id=eq.2", headers=headers)
    if resp.status_code != 200:
        print(f"Failed to fetch pillar: {resp.text}")
        return
    
    pillar_data = resp.json()[0]
    loc_data = pillar_data['localized_data']
    
    # Update localized_data
    for lang, trans in new_translations.items():
        loc_data[lang] = {
            "name": trans['name'],
            "description": trans['desc']
        }
    
    # Update global as well
    loc_data["global"] = {
        "name": new_translations['en']['name'],
        "description": new_translations['en']['desc']
    }
    
    # Patch back
    patch_resp = requests.patch(f"{url_base}/rest/v1/pillars?id=eq.2", headers=headers, json={"localized_data": loc_data})
    if patch_resp.status_code in [200, 204, 201]:
        print("Successfully updated pillar 2 to Health.")
    else:
        print(f"Failed to update pillar: {patch_resp.text}")

if __name__ == "__main__":
    update_pillar()
