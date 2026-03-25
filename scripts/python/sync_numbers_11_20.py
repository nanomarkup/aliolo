import urllib.request
import json
import ssl

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
USER_ID = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
SUBJECT_ID = "cb04da1c-9820-4e61-ae6b-bc7ed07eeb93"

HEADERS = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

context = ssl._create_unverified_context()

LANGS = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

NUM_MAP = {
    '11': {'ar': 'أحد عشر', 'bg': 'единадесет', 'cs': 'jedenáct', 'da': 'elleve', 'de': 'elf', 'el': 'έντεκα', 'en': 'eleven', 'es': 'once', 'et': 'üksteist', 'fi': 'yksitoista', 'fr': 'onze', 'ga': 'aon déag', 'hi': 'ग्यारह', 'hr': 'jedanaest', 'hu': 'tizenegy', 'id': 'sebelas', 'it': 'undici', 'ja': '十一', 'ko': '열하나', 'lt': 'vienuolika', 'lv': 'vienpadsmit', 'mt': 'ħdax', 'nl': 'elf', 'pl': 'jedenaście', 'pt': 'onze', 'ro': 'unsprezece', 'sk': 'jedenásť', 'sl': 'enajst', 'sv': 'elva', 'tl': 'labing-isa', 'tr': 'on bir', 'uk': 'одинадцять', 'vi': 'mười một', 'zh': '十一'},
    '12': {'ar': 'اثنا عشر', 'bg': 'дванадесет', 'cs': 'dvanáct', 'da': 'tolv', 'de': 'zwölf', 'el': 'δώδεκα', 'en': 'twelve', 'es': 'doce', 'et': 'kaksteist', 'fi': 'kaksitoista', 'fr': 'douze', 'ga': 'dó dhéag', 'hi': 'बारह', 'hr': 'dvanaest', 'hu': 'tizenkettő', 'id': 'dua belas', 'it': 'dodici', 'ja': '十二', 'ko': '열둘', 'lt': 'dvylika', 'lv': 'divpadsmit', 'mt': 'tnax', 'nl': 'twaalf', 'pl': 'dwanaście', 'pt': 'doze', 'ro': 'doisprezece', 'sk': 'dvanásť', 'sl': 'dvanajst', 'sv': 'tolv', 'tl': 'labindalawa', 'tr': 'on iki', 'uk': 'дванадцять', 'vi': 'mười hai', 'zh': '十二'},
    '13': {'ar': 'ثلاثة عشر', 'bg': 'тринадесет', 'cs': 'třináct', 'da': 'tretten', 'de': 'dreizehn', 'el': 'δεκατρία', 'en': 'thirteen', 'es': 'trece', 'et': 'kolmteist', 'fi': 'kolmetoista', 'fr': 'treize', 'ga': 'trí déag', 'hi': 'तेरह', 'hr': 'trinaest', 'hu': 'tizenhárom', 'id': 'tiga belas', 'it': 'tredici', 'ja': '十三', 'ko': '열셋', 'lt': 'trylika', 'lv': 'trīspadsmit', 'mt': 'tlettax', 'nl': 'dertien', 'pl': 'trzynaście', 'pt': 'treze', 'ro': 'treisprezece', 'sk': 'trinásť', 'sl': 'trinajst', 'sv': 'tretton', 'tl': 'labintatlo', 'tr': 'on üç', 'uk': 'тринадцять', 'vi': 'mười ba', 'zh': '十三'},
    '14': {'ar': 'أربعة عشر', 'bg': 'четиринадесет', 'cs': 'čtrnáct', 'da': 'fjorten', 'de': 'vierzehn', 'el': 'δεκατέσσερα', 'en': 'fourteen', 'es': 'catorce', 'et': 'neliteist', 'fi': 'neljätoista', 'fr': 'quatorze', 'ga': 'ceathair déag', 'hi': 'चौदह', 'hr': 'četrnaest', 'hu': 'tizennégy', 'id': 'empat belas', 'it': 'quattordici', 'ja': '十四', 'ko': '열넷', 'lt': 'keturiolika', 'lv': 'četrpadsmit', 'mt': 'erbatax', 'nl': 'veertien', 'pl': 'czternaście', 'pt': 'catorze', 'ro': 'paisprezece', 'sk': 'štrnásť', 'sl': 'štirinajst', 'sv': 'fjorton', 'tl': 'labing-apat', 'tr': 'on dört', 'uk': 'чотирнадцять', 'vi': 'mười bốn', 'zh': '十四'},
    '15': {'ar': 'خمسة عشر', 'bg': 'петнадесет', 'cs': 'patnáct', 'da': 'femten', 'de': 'fünfzehn', 'el': 'δεκαπέντε', 'en': 'fifteen', 'es': 'quince', 'et': 'viisteist', 'fi': 'viisitoista', 'fr': 'quinze', 'ga': 'cúig déag', 'hi': 'पंद्रह', 'hr': 'petnaest', 'hu': 'tizenöt', 'id': 'lima belas', 'it': 'quindici', 'ja': '十五', 'ko': '열다섯', 'lt': 'penkiolika', 'lv': 'piecpadsmit', 'mt': 'ħmistax', 'nl': 'vijftien', 'pl': 'piętnaście', 'pt': 'quinze', 'ro': 'cincisprezece', 'sk': 'pätnásť', 'sl': 'petnajst', 'sv': 'femten', 'tl': 'labinlima', 'tr': 'on beş', 'uk': 'п\'ятнадцять', 'vi': 'mười lăm', 'zh': '十五'},
    '16': {'ar': 'ستة عشر', 'bg': 'шестнадесет', 'cs': 'šestnáct', 'da': 'seksten', 'de': 'sechzehn', 'el': 'δεκαέξι', 'en': 'sixteen', 'es': 'dieciséis', 'et': 'kuusteist', 'fi': 'kuusitoista', 'fr': 'seize', 'ga': 'sé déag', 'hi': 'सोलह', 'hr': 'šesnaest', 'hu': 'tizenhat', 'id': 'enam belas', 'it': 'sedici', 'ja': '十六', 'ko': '열여섯', 'lt': 'šešiolika', 'lv': 'sešpadsmit', 'mt': 'sittax', 'nl': 'zestien', 'pl': 'szesnaście', 'pt': 'dezasseis', 'ro': 'șaisprezece', 'sk': 'šestnásť', 'sl': 'šestnajst', 'sv': 'sexton', 'tl': 'labing-anim', 'tr': 'on altı', 'uk': 'шістнадцять', 'vi': 'mười sáu', 'zh': '十六'},
    '17': {'ar': 'سبعة عشر', 'bg': 'седемнадесет', 'cs': 'sedmnáct', 'da': 'sytten', 'de': 'siebzehn', 'el': 'δεκαεπτά', 'en': 'seventeen', 'es': 'diecisiete', 'et': 'seitseteist', 'fi': 'seitsemäntoista', 'fr': 'dix-sept', 'ga': 'seacht déag', 'hi': 'सत्रह', 'hr': 'sedamnaest', 'hu': 'tizenhét', 'id': 'tujuh belas', 'it': 'diciassette', 'ja': '十七', 'ko': '열일곱', 'lt': 'septyniolika', 'lv': 'septiņpadsmit', 'mt': 'sbatax', 'nl': 'zeventien', 'pl': 'siedemnaście', 'pt': 'dezassete', 'ro': 'șaptesprezece', 'sk': 'sedemnásť', 'sl': 'sedemnajst', 'sv': 'sjutton', 'tl': 'labinpito', 'tr': 'on yedi', 'uk': 'сімнадцять', 'vi': 'mười bảy', 'zh': '十七'},
    '18': {'ar': 'ثمانية عشر', 'bg': 'осемнадесет', 'cs': 'osmnáct', 'da': 'atten', 'de': 'achtzehn', 'el': 'δεκαοκτώ', 'en': 'eighteen', 'es': 'dieciocho', 'et': 'kaheksateist', 'fi': 'kahdeksantoista', 'fr': 'dix-huit', 'ga': 'ocht déag', 'hi': 'अठارह', 'hr': 'osamnaest', 'hu': 'tizennyolc', 'id': 'delapan belas', 'it': 'diciotto', 'ja': '十八', 'ko': '열여덟', 'lt': 'aštuoniolika', 'lv': 'astoņpadsmit', 'mt': 'tmintax', 'nl': 'achttien', 'pl': 'osiemnaście', 'pt': 'dezoito', 'ro': 'optsprezece', 'sk': 'osemnášť', 'sl': 'osemnajst', 'sv': 'arton', 'tl': 'labing-walo', 'tr': 'on sekiz', 'uk': 'вісімнадцять', 'vi': 'mười tám', 'zh': '十八'},
    '19': {'ar': 'تسعة عشر', 'bg': 'деветнадесет', 'cs': 'devatenáct', 'da': 'nitten', 'de': 'neunzehn', 'el': 'δεκαεννέα', 'en': 'nineteen', 'es': 'diecinueve', 'et': 'üheksateist', 'fi': 'yhdeksäntoista', 'fr': 'dix-neuf', 'ga': 'naoi déag', 'hi': 'उन्नीस', 'hr': 'devetnaest', 'hu': 'tizenkilenc', 'id': 'sembilan belas', 'it': 'diciannove', 'ja': '十九', 'ko': '열아홉', 'lt': 'devyniolika', 'lv': 'deviņpadsmit', 'mt': 'dsatax', 'nl': 'negentien', 'pl': 'dziewiętnaście', 'pt': 'dezanove', 'ro': 'nouăsprezece', 'sk': 'devätnásť', 'sl': 'devetnajst', 'sv': 'nitton', 'tl': 'labinsiyam', 'tr': 'on dokuz', 'uk': 'дев\'ятнадцять', 'vi': 'mười chín', 'zh': '十九'},
    '20': {'ar': 'عشرون', 'bg': 'двадесет', 'cs': 'dvacet', 'da': 'tyve', 'de': 'zwanzig', 'el': 'είκοσι', 'en': 'twenty', 'es': 'veinte', 'et': 'kakskümmend', 'fi': 'kaksikymmentä', 'fr': 'vingt', 'ga': 'fiche', 'hi': 'बीस', 'hr': 'dvadeset', 'hu': 'húsz', 'id': 'dua puluh', 'it': 'venti', 'ja': '二十', 'ko': '스물', 'lt': 'dvidešimt', 'lv': 'divdesmit', 'mt': 'għoxrin', 'nl': 'twintig', 'pl': 'dwadzieścia', 'pt': 'vinte', 'ro': 'douăzeci', 'sk': 'dvadsať', 'sl': 'dvajset', 'sv': 'tjugo', 'tl': 'dalawampu', 'tr': 'yirmi', 'uk': 'двадцять', 'vi': 'hai mươi', 'zh': '二十'}
}

PROMPT_MAP = {
    "ar": "اختر الرقم الصحيح:", "bg": "Изберете правилното число:", "cs": "Vyberte správné číslo:", "da": "Vælg det rigtige tal:", "de": "Wählen Sie die richtige Zahl aus:", "el": "Επιλέξτε τον σωστό αριθμό:", "en": "Select the correct number:", "es": "Seleccione el número correcto:", "et": "Valige õige number:", "fi": "Valitse oikea numero:", "fr": "Sélectionnez le nombre correct :", "ga": "Roghnaigh an uimhir cheart:", "hi": "सही संख्या चुनें:", "hr": "Odaberite točan broj:", "hu": "Válassza ki a helyes számot!", "id": "Pilih nomor yang benar:", "it": "Seleziona il numero corretto:", "ja": "正しい番号を選択してください:", "ko": "올바른 숫자를 선택하세요:", "lt": "Pasirinkite teisingą skaičių:", "lv": "Izvēlieties pareizo numuru:", "mt": "Agħżel in-numru korrett:", "nl": "Selecteer het juiste getal:", "pl": "Wybierz poprawną liczbę:", "pt": "Selecione o número correto:", "ro": "Selectați numărul corect:", "sk": "Vyberte správne číslo:", "sl": "Izberite pravilno številko:", "sv": "Välj rätt nummer:", "tl": "Piliin ang tamang numero:", "tr": "Doğru sayıyı seçin:", "uk": "Оберіть правильне число:", "vi": "Chọn số đúng:", "zh": "选择正确的数字："
}

def sync_numbers():
    print("1. Updating Subject to 'Numbers 1-20'...")
    subject_translations = {
        "ar": "الأرقام ١-٢٠", "bg": "Числа 1-20", "cs": "Čísla 1-20", "da": "Tal 1-20", "de": "Zahlen 1-20", "el": "Αριθμοί 1-20", "en": "Numbers 1-20", "es": "Números 1-20", "et": "Numbrid 1-20", "fi": "Numerot 1-20", "fr": "Nombres 1-20", "ga": "Uimhreacha 1-20", "hi": "संख्या 1-20", "hr": "Brojevi 1-20", "hu": "Számok 1-20", "id": "Angka 1-20", "it": "Numeri 1-20", "ja": "数字 1-20", "ko": "숫자 1-20", "lt": "Skaičiai 1-20", "lv": "Skaitļи 1-20", "mt": "Numri 1-20", "nl": "Getallen 1-20", "pl": "Liczby 1-20", "pt": "Números 1-20", "ro": "Numere 1-20", "sk": "Čísla 1-20", "sl": "Števila 1-20", "sv": "Siffror 1-20", "tl": "Mga Numero 1-20", "tr": "Sayılar 1-20", "uk": "Числа 1-20", "vi": "Số 1-20", "zh": "数字 1-20"
    }
    sub_desc_translations = {
        "en": "Practice counting and recognizing numbers from 1 to 20.",
        "pl": "Ćwicz liczenie i rozpoznawanie liczb od 1 do 20."
        # descriptions for others can fallback to EN baseline
    }
    
    loc_data = {"global": {"name": "Numbers 1-20", "description": sub_desc_translations['en']}}
    for l in LANGS:
        loc_data[l] = {
            "name": subject_translations.get(l, "Numbers 1-20"),
            "description": sub_desc_translations.get(l, sub_desc_translations['en'])
        }
    
    req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/subjects?id=eq.{SUBJECT_ID}", headers=HEADERS, method="PATCH")
    urllib.request.urlopen(req, data=json.dumps({"localized_data": loc_data}).encode("utf-8"), context=context)
    print("  ✓ Subject updated.")

    print("\n2. Adding new cards for 11-20...")
    new_cards = []
    for i in range(11, 21):
        num_str = str(i)
        card_loc = {}
        
        # Audio & Image paths follow existing pattern
        # Image: numbers/num_img_X.png
        # Audio: numbers/LANG/audio_num_X_LANG.mp3
        
        # EN as source for all values
        en_val = NUM_MAP[num_str]['en']
        
        # Global fallback
        card_loc["global"] = {
            "prompt": PROMPT_MAP["en"],
            "answer": en_val,
            "audio_url": f"https://mltdjjszycfmokwqsqxm.supabase.co/storage/v1/object/public/card_audio/{USER_ID}/numbers/en/audio_num_{num_str}_en.mp3",
            "image_urls": [f"https://mltdjjszycfmokwqsqxm.supabase.co/storage/v1/object/public/card_images/{USER_ID}/numbers/num_img_{num_str}.png"]
        }
        
        for l in LANGS:
            # For new languages, try to use localized audio if available in storage, or fallback to EN audio
            # Based on inspection, some languages have actual localized audio paths
            card_loc[l] = {
                "prompt": PROMPT_MAP.get(l, PROMPT_MAP["en"]),
                "answer": NUM_MAP[num_str].get(l, en_val),
                "audio_url": f"https://mltdjjszycfmokwqsqxm.supabase.co/storage/v1/object/public/card_audio/{USER_ID}/numbers/{l}/audio_num_{num_str}_{l}.mp3"
            }
            
        new_cards.append({
            "subject_id": SUBJECT_ID,
            "owner_id": USER_ID,
            "level": 1,
            "test_mode": "image_to_text",
            "is_public": False,
            "localized_data": card_loc
        })

    # Bulk insert
    req = urllib.request.Request(f"{SUPABASE_URL}/rest/v1/cards", headers=HEADERS, method="POST")
    urllib.request.urlopen(req, data=json.dumps(new_cards).encode("utf-8"), context=context)
    print(f"  ✓ {len(new_cards)} new cards added.")

if __name__ == "__main__":
    sync_numbers()
