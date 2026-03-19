import urllib.request
import json
import ssl

SUPABASE_URL = "https://mltdjjszycfmokwqsqxm.supabase.co"
SERVICE_ROLE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"

translations = {
    "ar": {"next_daily_goal": "الهدف اليومي التالي", "goal_change_notice": "ستدخل التغييرات على هدفك اليومي حيز التنفيذ غداً."},
    "bg": {"next_daily_goal": "Следваща дневна цел", "goal_change_notice": "Промените в дневната ви цел ще влязат в сила от утре."},
    "cs": {"next_daily_goal": "Další denní cíl", "goal_change_notice": "Změny denního cíle se projeví zítra."},
    "da": {"next_daily_goal": "Næste daglige mål", "goal_change_notice": "Ændringer i dit daglige mål træder i kraft i morgen."},
    "de": {"next_daily_goal": "Nächstes Tagesziel", "goal_change_notice": "Änderungen an deinem Tagesziel werden morgen wirksam."},
    "el": {"next_daily_goal": "Επόμενος καθημερινός στόχος", "goal_change_notice": "Οι αλλαγές στον καθημερινό σας στόχο θα τεθούν σε ισχύ αύριο."},
    "en": {"next_daily_goal": "Next Daily Goal", "goal_change_notice": "Changes to your daily goal will take effect tomorrow."},
    "es": {"next_daily_goal": "Próximo objetivo diario", "goal_change_notice": "Los cambios en tu objetivo diario entrarán en vigor mañana."},
    "et": {"next_daily_goal": "Järgmine päevane eesmärk", "goal_change_notice": "Teie päevaeesmärgi muudatused jõustuvad homme."},
    "fi": {"next_daily_goal": "Seuraava päivätavoite", "goal_change_notice": "Päivätavoitteesi muutokset tulevat voimaan huomenna."},
    "fr": {"next_daily_goal": "Prochain objectif quotidien", "goal_change_notice": "Les modifications de votre objectif quotidien prendront effet demain."},
    "ga": {"next_daily_goal": "An chéad sprioc laethúil eile", "goal_change_notice": "Beidh athruithe ar do sprioc laethúil i bhfeidhm amárach."},
    "hi": {"next_daily_goal": "अगला दैनिक लक्ष्य", "goal_change_notice": "आपके दैनिक लक्ष्य में बदलाव कल से प्रभावी होंगे।"},
    "hr": {"next_daily_goal": "Sljedeći dnevni cilj", "goal_change_notice": "Promjene vašeg dnevnog cilja stupit će na snagu sutra."},
    "hu": {"next_daily_goal": "Következő napi cél", "goal_change_notice": "A napi célod módosításai holnap lépnek életbe."},
    "id": {"next_daily_goal": "Target Harian Berikutnya", "goal_change_notice": "Perubahan pada target harian Anda akan mulai berlaku besok."},
    "it": {"next_daily_goal": "Prossimo obiettivo giornaliero", "goal_change_notice": "Le modifiche al tuo obiettivo giornaliero entreranno in vigore domani."},
    "ja": {"next_daily_goal": "次の1日の目標", "goal_change_notice": "1日の目標への変更は明日から適用されます。"},
    "ko": {"next_daily_goal": "다음 일일 목표", "goal_change_notice": "일일 목표 변경 사항은 내일부터 적용됩니다."},
    "lt": {"next_daily_goal": "Kitas dienos tikslas", "goal_change_notice": "Dienos tikslo pakeitimai įsigalios rytoj."},
    "lv": {"next_daily_goal": "Nākamais dienas mērķis", "goal_change_notice": "Izmaiņas jūsu dienas mērķī stāsies spēkā rīt."},
    "mt": {"next_daily_goal": "L-Għan ta' Kuljum li Jmiss", "goal_change_notice": "Il-bidliet fl-għan ta' kuljum tiegħek se jidħlu fis-seħħ għada."},
    "nl": {"next_daily_goal": "Volgend dagelijks doel", "goal_change_notice": "Wijzigingen in je dagelijkse doel worden morgen van kracht."},
    "pl": {"next_daily_goal": "Następny dzienny cel", "goal_change_notice": "Zmiany w Twoim dziennym celu wejdą w życie jutro."},
    "pt": {"next_daily_goal": "Próximo objetivo diário", "goal_change_notice": "As alterações no seu objetivo diário entrarão em vigor amanhã."},
    "ro": {"next_daily_goal": "Următorul obiectiv zilnic", "goal_change_notice": "Modificările aduse obiectivului tău zilnic vor intra în vigoare mâine."},
    "sk": {"next_daily_goal": "Ďalší denný cieľ", "goal_change_notice": "Zmeny vášho denného cieľa nadobudnú účinnosť zajtra."},
    "sl": {"next_daily_goal": "Naslednji dnevni cilj", "goal_change_notice": "Spremembe vašega dnevnega cilja bodo začele veljati jutri."},
    "sv": {"next_daily_goal": "Nästa dagliga mål", "goal_change_notice": "Ändringar i ditt dagliga mål træder i kraft i morgon."},
    "tl": {"next_daily_goal": "Susunod na Pang-araw-araw na Layunin", "goal_change_notice": "Magkakabisa ang mga pagbabago sa iyong pang-araw-araw na layunin bukas."},
    "tr": {"next_daily_goal": "Sonraki Günlük Hedef", "goal_change_notice": "Günlük hedefinizdeki değişiklikler yarın yürürlüğe girecek."},
    "uk": {"next_daily_goal": "Наступна щоденна ціль", "goal_change_notice": "Зміни у вашій щоденній цілі наберуть чинності завтра."},
    "vi": {"next_daily_goal": "Mục tiêu hàng ngày tiếp theo", "goal_change_notice": "Các thay đổi đối với mục tiêu hàng ngày của bạn sẽ có hiệu lực vào ngày mai."},
    "zh": {"next_daily_goal": "下一个每日目标", "goal_change_notice": "您每日目标的更改将于明天生效。"}
}

data_to_upsert = []
for lang, texts in translations.items():
    for key, value in texts.items():
        data_to_upsert.append({
            "key": key,
            "lang": lang,
            "value": value
        })

url = f"{SUPABASE_URL}/rest/v1/ui_translations"
headers = {
    "apikey": SERVICE_ROLE_KEY,
    "Authorization": f"Bearer {SERVICE_ROLE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates"
}

context = ssl._create_unverified_context()

req = urllib.request.Request(url, headers=headers, data=json.dumps(data_to_upsert).encode("utf-8"), method="POST")

try:
    with urllib.request.urlopen(req, context=context) as response:
        print(f"Status: {response.status}")
        print(f"Response: {response.read().decode()}")
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code} {e.reason}")
    print(e.read().decode())
except Exception as e:
    print(f"Error: {e}")
