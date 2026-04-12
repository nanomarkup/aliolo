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

# Translations for "Bones of the Human Skeleton" and description
translations = {
    'en': {'name': 'Bones of the Human Skeleton', 'desc': 'Explore the 206 bones that form the human skeleton, from the skull to the toes.'},
    'ar': {'name': 'عظام الهيكل العظمي البشري', 'desc': 'اكتشف 206 عظمة تشكل الهيكل العظمي البشري، من الجمجمة إلى أصابع القدم.'},
    'bg': {'name': 'Кости на човешкия скелет', 'desc': 'Запознайте се с 206-те кости, които изграждат човешкия скелет – от черепа до пръстите на краката.'},
    'cs': {'name': 'Kosti lidského skeletu', 'desc': 'Objevte 206 kostí, které tvoří lidskou kostru, od lebky až po prsty u nohou.'},
    'da': {'name': 'Menneskets knogler', 'desc': 'Udforsk de 206 knogler, der danner det menneskelige skelet, fra kraniet til tæerne.'},
    'de': {'name': 'Knochen des menschlichen Skeletts', 'desc': 'Entdecken Sie die 206 Knochen, die das menschliche Skelett bilden, vom Schädel til zu den Zehen.'},
    'el': {'name': 'Οστά του Ανθρώπινου Σκελετού', 'desc': 'Εξερευνήστε τα 206 οστά που αποτελούν τον ανθρώπινο σκελετό, από το κρανίο μέχρι τα δάχτυλα των ποδιών.'},
    'es': {'name': 'Huesos del esqueleto humano', 'desc': 'Explora los 206 huesos que forman el esqueleto humano, desde el cráneo hasta los dedos de los pies.'},
    'et': {'name': 'Inimese luustiku luud', 'desc': 'Avastage 206 luud, mis moodustavad inimese skeleti, alates koljust kuni varvasteni.'},
    'fi': {'name': 'Ihmisen luurangon luut', 'desc': 'Tutustu ihmisen luurangon 206 luuhun pääkallosta varpaisiin asti.'},
    'fr': {'name': 'Os du squelette humain', 'desc': 'Découvrez les 206 os qui forment le squelette humain, du crâne aux orteils.'},
    'ga': {'name': 'Cnámha an Duine', 'desc': 'Déan iniúchadh ar an 206 cnámh atá i gcreatach an duine, ón gcloigeann go dtí na ladhra.'},
    'hi': {'name': 'मानव कंकाल की हड्डियाँ', 'desc': 'खोपड़ी से लेकर पैर की उंगलियों तक, मानव कंकाल बनाने वाली 206 हड्डियों का अन्वेषण करें।'},
    'hr': {'name': 'Kosti ljudskog kostura', 'desc': 'Istražite 206 kostiju koje čine ljudski kostur, od lubanje do nožnih prstiju.'},
    'hu': {'name': 'Az emberi csontváz csontjai', 'desc': 'Ismerje meg az emberi csontvázat alkotó 206 csontot a koponyától a lábujjakig.'},
    'id': {'name': 'Tulang Rangka Manusia', 'desc': 'Pelajari 206 tulang yang membentuk rangka manusia, mulai dari tengkorak hingga ujung kaki.'},
    'it': {'name': 'Ossa dello scheletro umano', 'desc': 'Esplora le 206 ossa che formano lo scheletro umano, dal cranio alle dita dei piedi.'},
    'ja': {'name': '人体の骨', 'desc': '頭蓋骨から足の先まで、人体の骨格を形成する206個の骨について学びましょう。'},
    'ko': {'name': '인체 골격의 뼈', 'desc': '두개골부터 발가락까지 인체 골격을 구성하는 206개의 뼈에 대해 알아보세요.'},
    'lt': {'name': 'Žmogaus skeleto kaulai', 'desc': 'Susipažinkite su 206 kaulais, sudarančiais žmogaus skeletą – nuo kaukolės iki kojų pirštų.'},
    'lv': {'name': 'Cilvēka skeleta kauli', 'desc': 'Iepazīstiet 206 kaulus, kas veido cilvēka skeletu, sākot no galvaskausa līdz kāju pirkstiem.'},
    'mt': {'name': 'Għadam tal-Iskeletru tal-Bniedem', 'desc': 'Esplora l-206 għadma li jiffurmaw l-iskeletru tal-bniedem, mill-kranju sa subgħajk.'},
    'nl': {'name': 'Botten van het menselijk skelet', 'desc': 'Ontdek de 206 botten die het menselijk skelet vormen, van de schedel tot de tenen.'},
    'pl': {'name': 'Kości szkieletu człowieka', 'desc': 'Poznaj 206 kości tworzących ludzki szkielet, od czaszki po palce u stóp.'},
    'pt': {'name': 'Ossos do Esqueleto Humano', 'desc': 'Explore os 206 ossos que formam o esqueleto humano, do crânio aos dedos dos pés.'},
    'ro': {'name': 'Oasele scheletului uman', 'desc': 'Explorează cele 206 oase care formează scheletul uman, de la craniu până la degetele de la picioare.'},
    'sk': {'name': 'Kosti ľudskej kostry', 'desc': 'Objavte 206 kostí, ktoré tvoria ľudskú kostru, od lebky až po prsty na nohách.'},
    'sl': {'name': 'Kosti človeškega okostja', 'desc': 'Spoznajte 206 kosti, ki sestavljajo človeško okostje, od lobanje do prstov na nogah.'},
    'sv': {'name': 'Människans skelettben', 'desc': 'Utforska de 206 ben som bildar det mänskliga skelettet, från kraniet till tårna.'},
    'tl': {'name': 'Mga Buto ng Kalansay ng Tao', 'desc': 'Tuklasin ang 206 na buto na bumubuo sa kalansay ng tao, mula sa bungo hanggang sa mga daliri sa paa.'},
    'tr': {'name': 'İnsan İskeleti Kemikleri', 'desc': 'Kafatasıdan ayak parmaklarına kadar insan iskeletini oluşturan 206 kemiği keşfedin.'},
    'uk': {'name': 'Кістки скелета людини', 'desc': 'Дізнайтеся про 206 кісток, що складають скелет людини: від черепа до пальців ніг.'},
    'vi': {'name': 'Các xương trong cơ thể người', 'desc': 'Khám phá 206 mảnh xương hình thành nên bộ xương người, từ hộp sọ đến các ngón chân.'},
    'zh': {'name': '人体骨骼', 'desc': '探索构成人体骨骼的 206 块骨头，从头骨到脚趾。'}
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
