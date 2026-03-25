import urllib.request
import json
import ssl
import os
import time
import subprocess

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
USER_ID = "f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac"
PILLAR_ID = 8 # Other

TTS_URL = "https://translate.google.com/translate_tts?ie=UTF-8&q={text}&tl={lang}&client=tw-ob"

LANGS_TTS = {
    'ar': 'ar', 'bg': 'bg', 'cs': 'cs', 'da': 'da', 'de': 'de', 'el': 'el', 'en': 'en', 'es': 'es', 'et': 'et', 'fi': 'fi', 'fr': 'fr', 'hi': 'hi', 'hr': 'hr', 'hu': 'hu', 'id': 'id', 'it': 'it', 'ja': 'ja', 'ko': 'ko', 'lt': 'lt', 'lv': 'lv', 'mt': 'mt', 'nl': 'nl', 'pl': 'pl', 'pt': 'pt', 'ro': 'ro', 'sk': 'sk', 'sl': 'sl', 'sv': 'sv', 'tl': 'tl', 'tr': 'tr', 'uk': 'uk', 'vi': 'vi', 'zh': 'zh-CN'
}

from alphabet_map import ALPHABET_MAP

# Core Prompt Map
PROMPT_MAP = {
    "en": "Select the correct letter:",
    "ar": "اختر الحرف الصحيح:", "bg": "Изберете правилната буква:", "cs": "Vyberte správné písmeno:", "da": "Vælg det rigtige bogstav:", "de": "Wählen Sie den richtigen Buchstaben aus:", "el": "Επιλέξτε το σωστό γράμμα:", "es": "Seleccione la letra correcta:", "et": "Valige õige täht:", "fi": "Valitse oikea kirjain:", "fr": "Sélectionnez la lettre correcte :", "ga": "Roghnaigh an litir cheart:", "hi": "सही अक्षर चुनें:", "hr": "Odaberite točno slovo:", "hu": "Válassza ki a helyes betűt!", "id": "Pilih huruf yang benar:", "it": "Seleziona la lettera corretta:", "ja": "正しい文字を選択してください:", "ko": "올바른 글자를 선택하세요:", "lt": "Pasirinkite teisingą raidę:", "lv": "Izvēlieties pareizo burtu:", "mt": "Agħżel l-ittra t-tajba:", "nl": "Selecteer de juiste letter:", "pl": "Wybierz poprawną literę:", "pt": "Selecione a letra correta:", "ro": "Selectați litera corectă:", "sk": "Vyberte správne písmeno:", "sl": "Izberite pravilno črko:", "sv": "Välj rätt bokstav:", "tl": "Piliin ang tamang titik:", "tr": "Doğru harfi seçin:", "uk": "Оберіть правильну літеру:", "vi": "Chọn chữ cái đúng:", "zh": "选择正确的字母："
}

# Simplified Subject Names Map (Language + " Alphabet")
# Native names for languages
NATIVE_LANG_NAMES = {
    'ar': 'العربية', 'bg': 'Българска', 'cs': 'Česká', 'da': 'Dansk', 'de': 'Deutsche', 'el': 'Ελληνική', 'en': 'English', 'es': 'Española', 'et': 'Eesti', 'fi': 'Suomen', 'fr': 'Française', 'ga': 'Gaeilge', 'hi': 'हिन्दी', 'hr': 'Hrvatska', 'hu': 'Magyar', 'id': 'Indonesia', 'it': 'Italiana', 'ja': '日本語', 'ko': '한국어', 'lt': 'Lietuvių', 'lv': 'Latviešu', 'mt': 'Malti', 'nl': 'Nederlandse', 'pl': 'Polska', 'pt': 'Portuguesa', 'ro': 'Română', 'sk': 'Slovenská', 'sl': 'Slovenska', 'sv': 'Svenska', 'tl': 'Tagalog', 'tr': 'Türk', 'uk': 'Українська', 'vi': 'Tiếng Việt', 'zh': '中文'
}

context = ssl._create_unverified_context()

def make_request(url, method="GET", data=None):
    headers = {
        "apikey": SERVICE_ROLE_KEY,
        "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
        "Content-Type": "application/json"
    }
    req = urllib.request.Request(url, headers=headers, method=method)
    if data:
        req.data = json.dumps(data).encode("utf-8")
    try:
        with urllib.request.urlopen(req, context=context) as response:
            if response.status >= 200 and response.status < 300:
                body = response.read().decode("utf-8")
                return json.loads(body) if body else True
            return False
    except Exception as e:
        print(f"Error ({url}): {e}")
        return False

def generate_alphabet_subjects():
    print("--- STARTING MASS ALPHABET GENERATION ---")
    
    # Sort languages to ensure consistency
    all_langs = sorted(ALPHABET_MAP.keys())
    
    for target_lang in all_langs:
        # 1. Create Subject
        subject_name_en = f"{NATIVE_LANG_NAMES['en']} {target_lang.upper()} Alphabet" if target_lang != 'en' else "English Alphabet"
        # Try to use existing subject or create new
        # For simplicity, we create new ones.
        
        loc_subject = {"global": {"name": f"{target_lang.upper()} Alphabet", "description": f"Learn the {target_lang.upper()} alphabet."}}
        for ui_l in all_langs:
            loc_subject[ui_l] = {
                "name": f"{NATIVE_LANG_NAMES.get(target_lang, target_lang.upper())} Alphabet",
                "description": f"Learn the letters and sounds of the {target_lang.upper()} language."
            }
            
        subject_payload = {
            "pillar_id": PILLAR_ID,
            "owner_id": USER_ID,
            "is_public": True,
            "localized_data": loc_subject
        }
        
        print(f"\nCreating subject: {target_lang.upper()} Alphabet...")
        res = make_request(f"{SUPABASE_URL}/rest/v1/subjects", method="POST", data=subject_payload)
        # Fetch the newly created ID (using Prefer: return=representation would be easier, but let's just fetch it)
        time.sleep(0.5)
        latest = make_request(f"{SUPABASE_URL}/rest/v1/subjects?owner_id=eq.{USER_ID}&order=created_at.desc&limit=1")
        if not latest: continue
        subject_id = latest[0]['id']
        
        # 2. Generate and Upload assets for each character
        chars = ALPHABET_MAP[target_lang]
        print(f"  Processing {len(chars)} characters...")
        
        for char in chars:
            # Filenames
            safe_char = "".join([c for c in char if c.isalnum()]) or "char"
            img_filename = f"alpha_{target_lang}_{safe_char}.png"
            audio_filename = f"audio_{target_lang}_{safe_char}.mp3"
            
            # A. Generate Image (FFmpeg)
            # Background colors per language or random? Let's use a nice Indigo
            bg_color = "#3F51B5" 
            try:
                subprocess.run([
                    "ffmpeg", "-y", "-f", "lavfi", "-i", f"color=c='{bg_color}':s=512x512:d=1",
                    "-vf", f"drawtext=text='{char}':fontcolor=white:fontsize=300:x=(w-text_w)/2:y=(h-text_h)/2",
                    "-frames:v", "1", "-update", "1", img_filename
                ], capture_output=True)
                
                # Upload Image
                with open(img_filename, "rb") as f:
                    img_data = f.read()
                img_url = f"{SUPABASE_URL}/storage/v1/object/card_images/{USER_ID}/alphabets/{target_lang}/{img_filename}"
                headers = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "image/png", "x-upsert": "true"}
                urllib.request.urlopen(urllib.request.Request(img_url, headers=headers, data=img_data, method="POST"), context=context)
                os.remove(img_filename)
            except Exception as e:
                print(f"    ! Image error for {char}: {e}")

            # B. Generate Audio (TTS)
            audio_public_url = None
            if target_lang in LANGS_TTS:
                try:
                    tts_lang = LANGS_TTS[target_lang]
                    safe_text = urllib.parse.quote(char)
                    tts_url = TTS_URL.format(text=safe_text, lang=tts_lang)
                    tts_req = urllib.request.Request(tts_url, headers={'User-Agent': 'Mozilla/5.0'})
                    with urllib.request.urlopen(tts_req, context=context) as tts_res:
                        audio_data = tts_res.read()
                    
                    audio_url = f"{SUPABASE_URL}/storage/v1/object/card_audio/{USER_ID}/alphabets/{target_lang}/{audio_filename}"
                    headers = {"apikey": SERVICE_ROLE_KEY, "Authorization": f"Bearer {SERVICE_ROLE_KEY}", "Content-Type": "audio/mpeg", "x-upsert": "true"}
                    urllib.request.urlopen(urllib.request.Request(audio_url, headers=headers, data=audio_data, method="POST"), context=context)
                    audio_public_url = f"{SUPABASE_URL}/storage/v1/object/public/card_audio/{USER_ID}/alphabets/{target_lang}/{audio_filename}"
                except Exception as e:
                    print(f"    ! Audio error for {char}: {e}")

            # 3. Create Card
            img_public_url = f"{SUPABASE_URL}/storage/v1/object/public/card_images/{USER_ID}/alphabets/{target_lang}/{img_filename}"
            
            loc_card = {
                "global": {
                    "prompt": PROMPT_MAP.get(target_lang, PROMPT_MAP["en"]),
                    "answer": char,
                    "image_urls": [img_public_url],
                    "audio_url": audio_public_url
                },
                target_lang: {
                    "prompt": PROMPT_MAP.get(target_lang, PROMPT_MAP["en"]),
                    "answer": char,
                    "audio_url": audio_public_url
                }
            }
            
            card_payload = {
                "subject_id": subject_id,
                "owner_id": USER_ID,
                "level": 1,
                "test_mode": "audio_to_image",
                "is_public": True,
                "localized_data": loc_card
            }
            make_request(f"{SUPABASE_URL}/rest/v1/cards", method="POST", data=card_payload)
            time.sleep(0.1)
            
        print(f"  ✓ {target_lang.upper()} Alphabet complete.")

if __name__ == "__main__":
    generate_alphabet_subjects()
