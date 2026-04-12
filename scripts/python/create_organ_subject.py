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

pillar_id = 2
owner_id = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

# Translations for "Human Organ Systems" and description
translations = {
    'en': {'name': 'Human Organ Systems', 'desc': 'Learn about the complex systems that keep the human body functioning, from digestion to the nervous system.'},
    'ar': {'name': 'أجهزة جسم الإنسان', 'desc': 'تعرف على الأنظمة المعقدة التي تحافظ على عمل جسم الإنسان، من الهضم إلى الجهاز العصبي.'},
    'bg': {'name': 'Органни системи на човека', 'desc': 'Научете за сложните системи, които поддържат функционирането на човешкото тяло – от храносмилането до нервната система.'},
    'cs': {'name': 'Lidské orgánové soustavy', 'desc': 'Dozvíte se o složitých systémech, které udržují lidské tělo v chodu, od trávení až po nervovou soustavu.'},
    'da': {'name': 'Menneskets organsystemer', 'desc': 'Lær om de komplekse systemer, der holder menneskekroppen i gang, fra fordøjelse til nervesystemet.'},
    'de': {'name': 'Menschliche Organsysteme', 'desc': 'Lernen Sie die komplexen Systeme kennen, die den menschlichen Körper am Laufen halten, von der Verdauung bis zum Nervensystem.'},
    'el': {'name': 'Συστήματα οργάνων του ανθρώπου', 'desc': 'Μάθετε για τα πολύπλοκα συστήματα που διατηρούν τη λειτουργία του ανθρώπινου σώματος, από την πέψη μέχρι το νευρικό σύστημα.'},
    'es': {'name': 'Sistemas de órganos humanos', 'desc': 'Aprenda sobre los complejos sistemas που mantienen el cuerpo humano en funcionamiento, desde la digestión hasta el sistema nervioso.'},
    'et': {'name': 'Inimese elundkonnad', 'desc': 'Õppige tundma keerukaid süsteeme, mis hoiavad inimkeha toimimas, alates seedimisest kuni närvisüsteemini.'},
    'fi': {'name': 'Ihmisen elinjärjestelmät', 'desc': 'Opi monimutkaisista järjestelmistä, jotka pitävät ihmiskehon toiminnassa ruoansulatuksesta hermostoon.'},
    'fr': {'name': 'Systèmes d\'organes humains', 'desc': 'Découvrez les systèmes complexes qui assurent le fonctionnement du corps humain, de la digestion au système nerveux.'},
    'ga': {'name': 'Córais Orgán Daonna', 'desc': 'Foghlaim faoi na córais chasta a choinníonn corp an duine ag feidhmiú, ón díleá go dtí an néarchóras.'},
    'hi': {'name': 'मानव अंग प्रणाली', 'desc': 'पाचन से लेकर तंत्रिका तंत्र तक, उन जटिल प्रणालियों के बारे में जानें जो मानव शरीर को कार्यशील रखती हैं।'},
    'hr': {'name': 'Ljudski organski sustavi', 'desc': 'Saznajte više o složenim sustavima koji održavaju ljudsko tijelo u funkciji, od probave do živčanog sustava.'},
    'hu': {'name': 'Emberi szervrendszerek', 'desc': 'Ismerje meg azokat az összetett rendszereket, amelyek az emberi test működését biztosítják, az emésztéstől az idegrendszerig.'},
    'id': {'name': 'Sistem Organ Manusia', 'desc': 'Pelajari tentang sistem kompleks yang menjaga tubuh manusia tetap berfungsi, mulai dari pencernaan hingga sistem saraf.'},
    'it': {'name': 'Sistemi di organi umani', 'desc': 'Scopri i complessi sistemi che mantengono il corpo umano in funzione, dalla digestione al sistema nervoso.'},
    'ja': {'name': '人体の器官系', 'desc': '消化器系から神経系まで、人体の機能を維持する複雑なシステムについて学びましょう。'},
    'ko': {'name': '인체 기관계', 'desc': '소화기 계통부터 신경계까지 인체의 기능을 유지하는 복잡한 계통에 대해 알아보세요.'},
    'lt': {'name': 'Žmogaus organų sistemos', 'desc': 'Sužinokite apie sudėtingas sistemas, palaikančias žmogaus kūno veiklą – nuo virškinimo iki nervų sistemos.'},
    'lv': {'name': 'Cilvēka orgānu sistēmas', 'desc': 'Uzziniet par sarežģītajām sistēmām, kas nodrošina cilvēka ķermeņa darbību, sākot no gremošanas līdz nervu sistēmai.'},
    'mt': {'name': 'Sistemi ta\' Organi tal-Bniedem', 'desc': 'Tgħallem dwar is-sistemi kumplessi li jżommu l-ġisem tal-bniedem jaħdem, mid-diġestjoni sas-sistema nervuża.'},
    'nl': {'name': 'Menselijke orgaansystemen', 'desc': 'Leer meer over de complexe systemen die het menselijk lichaam laten functioneren, van de spijsvertering tot het zenuwstelsel.'},
    'pl': {'name': 'Układy narządów człowieka', 'desc': 'Poznaj złożone układy, które zapewniają funkcjonowanie ludzkiego ciała, od trawienia po układ nerwowy.'},
    'pt': {'name': 'Sistemas de Órgãos Humanos', 'desc': 'Aprenda sobre os sistemas complexos que mantêm o corpo humano funcionando, desde a digestão até o sistema nervoso.'},
    'ro': {'name': 'Sisteme de organe umane', 'desc': 'Aflați despre sistemele complexe care mențin corpul uman în funcțiere, de la digestie la sistemul nervos.'},
    'sk': {'name': 'Ľudské orgánové sústavy', 'desc': 'Dozviete sa o zložitých systémoch, ktoré udržujú ľudské telo v chode, od trávenia až po nervovú sústavu.'},
    'sl': {'name': 'Človeški organski sistemi', 'desc': 'Spoznajte zapletene sisteme, ki ohranjajo delovanje človeškega telesa, od prebave do živčnega sistema.'},
    'sv': {'name': 'Människans organsystem', 'desc': 'Lär dig om de komplexa system som håller människokroppen igång, från matsmältningen till nervsystemet.'},
    'tl': {'name': 'Mga Sistema ng Organ ng Tao', 'desc': 'Alamin ang tungkol sa mga kumplikadong sistema na nagpapanatili sa paggana ng katawan ng tao, mula sa panunaw hanggang sa nervous system.'},
    'tr': {'name': 'İnsan Organ Sistemleri', 'desc': 'Sindirimden sinir sistemine kadar insan vücudunun çalışmasını sağlayan karmaşık sistemler hakkında bilgi edinin.'},
    'uk': {'name': 'Системи органів людини', 'desc': 'Дізнайтеся про складні системи, які забезпечують функціонування людського тіла: від травлення до нервової системи.'},
    'vi': {'name': 'Các hệ cơ quan ở người', 'desc': 'Tìm hiểu về các hệ thống phức tạp giúp cơ thể con người hoạt động, từ hệ tiêu hóa đến hệ thần kinh.'},
    'zh': {'name': '人体器官系统', 'desc': '了解维持人体运转的复杂系统，从消化系统到神经系统。'}
}

def create_subject():
    loc_data = {}
    for lang in langs:
        t = translations.get(lang, translations['en'])
        loc_data[lang] = {
            "name": t['name'],
            "description": t['desc']
        }
    
    loc_data["global"] = {
        "name": translations['en']['name'],
        "description": translations['en']['desc']
    }
    
    payload = {
        "pillar_id": pillar_id,
        "owner_id": owner_id,
        "is_public": True,
        "age_group": "15_plus",
        "localized_data": loc_data
    }
    
    resp = requests.post(f"{url_base}/rest/v1/subjects", headers=headers, json=payload)
    if resp.status_code in [200, 201]:
        created = resp.json()[0]
        print(f"Created subject: {created['id']}")
        return created['id']
    else:
        print(f"Failed to create subject: {resp.text}")
        return None

if __name__ == "__main__":
    create_subject()
