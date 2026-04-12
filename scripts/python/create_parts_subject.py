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

# Translations for "Parts of Human Body" and description
translations = {
    'en': {'name': 'Parts of Human Body', 'desc': 'Explore the different parts of the human body, from the head to the limbs.'},
    'ar': {'name': 'أجزاء جسم الإنسان', 'desc': 'اكتشف أجزاء جسم الإنسان المختلفة، من الرأس إلى الأطراف.'},
    'bg': {'name': 'Части на човешкото тяло', 'desc': 'Запознайте се с различните части на човешкото тяло – от главата до крайниците.'},
    'cs': {'name': 'Části lidského těla', 'desc': 'Objevte různé části lidského těla, od hlavy až po končetiny.'},
    'da': {'name': 'Kropsdele', 'desc': 'Udforsk de forskellige dele af den menneskelige krop, fra hovedet til lemmerne.'},
    'de': {'name': 'Teile des menschlichen Körpers', 'desc': 'Entdecken Sie die verschiedenen Teile des menschlichen Körpers, vom Kopf bis zu den Gliedmaßen.'},
    'el': {'name': 'Μέρη του ανθρώπινου σώματος', 'desc': 'Εξερευνήστε τα διάφορα μέρη του ανθρώπινου σώματος, από το κεφάλι μέχρι τα άκρα.'},
    'es': {'name': 'Partes del cuerpo humano', 'desc': 'Explora las diferentes partes del cuerpo humano, desde la cabeza hasta las extremidades.'},
    'et': {'name': 'Inimese kehaosad', 'desc': 'Avastage inimese keha eri osi peast jäsemeteni.'},
    'fi': {'name': 'Ihmiskehon osat', 'desc': 'Tutustu ihmiskehon eri osiin päästä raajoihin.'},
    'fr': {'name': 'Parties du corps humain', 'desc': 'Découvrez les différentes parties du corps humain, de la tête aux membres.'},
    'ga': {'name': 'Baill an Choirp', 'desc': 'Déan iniúchadh ar chodanna éagsúla de chorp an duine, ón gcloigeann go dtí na géaga.'},
    'hi': {'name': 'मानव शरीर के अंग', 'desc': 'सिर से लेकर हाथ-पैर तक मानव शरीर के विभिन्न अंगों का अन्वेषण करें।'},
    'hr': {'name': 'Dijelovi ljudskog tijela', 'desc': 'Istražite različite dijelove ljudskog tijela, od glave do udova.'},
    'hu': {'name': 'Az emberi test részei', 'desc': 'Ismerje meg az emberi test különböző részeit a fejtől a végtagokig.'},
    'id': {'name': 'Bagian Tubuh Manusia', 'desc': 'Pelajari berbagai bagian tubuh manusia, dari kepala hingga anggota gerak.'},
    'it': {'name': 'Parti del corpo umano', 'desc': 'Esplora le diverse parti del corpo umano, dalla testa agli arti.'},
    'ja': {'name': '人体の部位', 'desc': '頭から手足まで、人体のさまざまな部位について学びましょう。'},
    'ko': {'name': '인체의 부위', 'desc': '머리부터 팔다리까지 인체의 다양한 부위에 대해 알아보세요.'},
    'lt': {'name': 'Žmogaus kūno dalys', 'desc': 'Susipažinkite su įvairiomis žmogaus kūno dalimis – nuo galvos iki galūnių.'},
    'lv': {'name': 'Cilvēka ķermeņa daļas', 'desc': 'Iepazīstiet dažādas cilvēka ķermeņa daļas no galvas līdz locekļiem.'},
    'mt': {'name': 'Partijiet tal-Ġisem tal-Bniedem', 'desc': 'Esplora l-partijiet differenti tal-ġisem tal-bniedem, mir-ras sa l-estremitajiet.'},
    'nl': {'name': 'Lichaamsdelen', 'desc': 'Ontdek de verschillende delen van het menselijk lichaam, van het hoofd tot de ledematen.'},
    'pl': {'name': 'Części ciała ludzkiego', 'desc': 'Poznaj różne części ludzkiego ciała, od głowy po kończyny.'},
    'pt': {'name': 'Partes do Corpo Humano', 'desc': 'Explore as diferentes partes do corpo humano, da cabeça aos membros.'},
    'ro': {'name': 'Părțile corpului uman', 'desc': 'Explorează diferitele părți ale corpului uman, de la cap până la membre.'},
    'sk': {'name': 'Časti ľudského tela', 'desc': 'Objavte rôzne časti ľudského tela, od hlavy až po končatiny.'},
    'sl': {'name': 'Deli človeškega telesa', 'desc': 'Spoznajte različne dele človeškega teleska, od glave do okončin.'},
    'sv': {'name': 'Människans kroppsdelar', 'desc': 'Utforska människokroppens olika delar, från huvudet till lemmarna.'},
    'tl': {'name': 'Mga Bahagi ng Katawan ng Tao', 'desc': 'Alamin ang tungkol sa iba\'t ibang bahagi ng katawan ng tao, mula sa ulo hanggang sa mga paa\'t kamay.'},
    'tr': {'name': 'İnsan Vücudunun Bölümleri', 'desc': 'Kafadan uzuvlara kadar insan vücudunun farklı bölümlerini keşfedin.'},
    'uk': {'name': 'Частини тіла людини', 'desc': 'Дізнайтеся про різні частини людського тіла: від голови до кінцівок.'},
    'vi': {'name': 'Các bộ phận trên cơ thể người', 'desc': 'Khám phá các bộ phận khác nhau của cơ thể người, từ đầu đến tay chân.'},
    'zh': {'name': '人体部位', 'desc': '探索人体的不同部位，从头部到四肢。'}
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
        "age_group": "0_6",
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
