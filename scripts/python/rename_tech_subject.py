import requests
import json

url_base = "https://mltdjjszycfmokwqsqxm.supabase.co"
apikey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1sdGRqanN6eWNmbW9rd3FzcXhtIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3MzEzMjg4NywiZXhwIjoyMDg4NzA4ODg3fQ.3HE7aC6ByeLFPKhErJNy40WO2vaO8tagl4UR0CnoHWI"
headers = {
    "apikey": apikey,
    "Authorization": f"Bearer {apikey}",
    "Content-Type": "application/json",
    "Prefer": "return=minimal"
}

subject_id = "8db933e6-8906-4e4b-86f5-7c863fe1ef01"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

# Translations for "Modern Gadgets & Technology"
translations = {
    'en': {'name': 'Modern Gadgets & Technology', 'desc': 'Discover the innovative devices and technology that shape our daily lives, from smartwatches to drones.'},
    'ar': {'name': 'الأجهزة والتقنيات الحديثة', 'desc': 'اكتشف الأجهزة والتقنيات المبتكرة التي تشكل حياتنا اليومية، من الساعات الذكية إلى الطائرات بدون طيار.'},
    'bg': {'name': 'Модерни джаджи и технологии', 'desc': 'Открийте иновативните устройства и технологии, които оформят нашето ежедневие – от смарт часовници до дронове.'},
    'cs': {'name': 'Moderní gadgety a technologie', 'desc': 'Objevte inovativní zařízení a technologie, které formují náš každodenní život, od chytrých hodinek po drony.'},
    'da': {'name': 'Moderne gadgets og teknologi', 'desc': 'Oplev de innovative enheder og teknologier, der former vores hverdag, fra smartwatches til droner.'},
    'de': {'name': 'Moderne Gadgets & Technologie', 'desc': 'Entdecken Sie die innovativen Geräte und Technologien, die unseren Alltag prägen, von Smartwatches bis hin zu Drohnen.'},
    'el': {'name': 'Σύγχρονα Gadgets & Τεχνολογία', 'desc': 'Ανακαλύψτε τις καινοτόμες συσκευές και την τεχνολογία που διαμορφώνουν την καθημερινότητά μας, από έξυπνα ρολόγια μέχρι drones.'},
    'es': {'name': 'Gadgets y Tecnología Moderna', 'desc': 'Descubre los dispositivos y la tecnología innovadores que dan forma a nuestra vida diaria, desde relojes inteligentes hasta drones.'},
    'et': {'name': 'Kaasaegsed vidinad ja tehnoloogia', 'desc': 'Avastage uuenduslikud seadmed ja tehnoloogia, mis kujundavad meie igapäevaelu, nutikelladest droonideni.'},
    'fi': {'name': 'Nykyaikaiset vempaimet ja teknologia', 'desc': 'Tutustu innovatiivisiin laitteisiin ja teknologiaan, jotka muokkaavat jokapäiväistä elämäämme älykelloista drooneihin.'},
    'fr': {'name': 'Gadgets et technologies modernes', 'desc': 'Découvrez les appareils et technologies innovants qui façonnent notre quotidien, des montres connectées aux drones.'},
    'ga': {'name': 'Gairis & Teicneolaíocht Nua-Aimseartha', 'desc': 'Faigh amach faoi na gairis agus an teicneolaíocht nuálach a mhúnlaíonn ár saol laethúil, ó uaireadóirí cliste go drones.'},
    'hi': {'name': 'आधुनिक गैजेट्स और तकनीक', 'desc': 'स्मार्टवॉच से लेकर ड्रोन तक, हमारे दैनिक जीवन को आकार देने वाले अभिनव उपकरणों और तकनीक की खोज करें।'},
    'hr': {'name': 'Moderni uređaji i tehnologija', 'desc': 'Otkrijte inovativne uređaje i tehnologiju koji oblikuju naš svakodnevni život, od pametnih satova do dronova.'},
    'hu': {'name': 'Modern kütyük és technológia', 'desc': 'Fedezze fel azokat az innovatív eszközöket és technológiákat, amelyek mindennapi életünket alakítják, az okosóráktól a drónokig.'},
    'id': {'name': 'Gadget & Teknologi Modern', 'desc': 'Temukan perangkat dan teknologi inovatif yang membentuk kehidupan kita sehari-hari, mulai dari jam tangan pintar hingga drone.'},
    'it': {'name': 'Gadget e tecnologia moderni', 'desc': 'Scopri i dispositivi e la tecnologia innovativi che modellano la nostra vita quotidiana, dagli smartwatch ai droni.'},
    'ja': {'name': '最新ガジェットとテクノロジー', 'desc': 'スマートウォッチからドローンまで、私たちの日常生活を形作る革新的なデバイスとテクノロジーを発見してください。'},
    'ko': {'name': '현대 가젯 및 기술', 'desc': '스마트워치부터 드론까지 일상을 형성하는 혁신적인 기기와 기술을 만나보세요.'},
    'lt': {'name': 'Modernūs programėlės ir technologijos', 'desc': 'Atraskite naujoviškus įrenginius ir technologijas, formuojančias mūsų kasdienį gyvenimą – nuo išmaniųjų laikrodžių iki dronų.'},
    'lv': {'name': 'Mūsdienu sīkrīki un tehnoloģijas', 'desc': 'Atklājiet inovatīvas ierīces un tehnoloģijas, kas veido mūsu ikdienu, no viedpulksteņiem līdz droniem.'},
    'mt': {'name': 'Gadgets u Teknoloġija Moderni', 'desc': 'Skopri l-apparati u t-teknoloġija innovattivi li jsawru l-ħajja tagħna ta\' kuljum, minn smartwatches sa drones.'},
    'nl': {'name': 'Moderne gadgets & technologie', 'desc': 'Ontdek de innovatieve apparaten en technologie die ons dagelijks leven vormgeven, van smartwatches tot drones.'},
    'pl': {'name': 'Nowoczesne gadżety i technologia', 'desc': 'Poznaj innowacyjne urządzenia i technologie, które kształtują nasze codzienne życie, od smartwatchy po drony.'},
    'pt': {'name': 'Gadgets e Tecnologia Modernos', 'desc': 'Descubra os dispositivos e tecnologias inovadores que moldam o nosso dia-a-dia, desde smartwatches a drones.'},
    'ro': {'name': 'Gadgeturi și tehnologie modernă', 'desc': 'Descoperiți dispozitivele și tehnologia inovatoare care ne modelează viața de zi cu zi, de la ceasuri inteligente la drone.'},
    'sk': {'name': 'Moderné gadgety a technológie', 'desc': 'Objavte inovatívne zariadenia a technológie, ktoré formujú náš každodenný život, od inteligentných hodiniek po drony.'},
    'sl': {'name': 'Sodobni pripomočki in tehnologija', 'desc': 'Odkrijte inovativne naprave in tehnologijo, ki oblikujejo naše vsakdanje življenje, od pametnih ur do dronov.'},
    'sv': {'name': 'Moderna prylar och teknik', 'desc': 'Upptäck de innovativa enheterna och tekniken som formar vår vardag, från smartklockor till drönare.'},
    'tl': {'name': 'Mga Modernong Gadget at Teknolohiya', 'desc': 'Tuklasin ang mga makabagong device at teknolohiya na humuhubog sa ating pang-araw-araw na buhay, mula sa mga smartwatch hanggang sa mga drone.'},
    'tr': {'name': 'Modern Gadgetlar ve Teknoloji', 'desc': 'Akıllı saatlerden dronlara kadar günlük hayatımızı şekillendiren yenilikçi cihazları ve teknolojiyi keşfedin.'},
    'uk': {'name': 'Сучасні гаджети та технології', 'desc': 'Відкрийте для себе інноваційні пристрої та технології, що формують наше повсякденне життя: від смарт-годинників до дронів.'},
    'vi': {'name': 'Gadget & Công nghệ hiện đại', 'desc': 'Khám phá các thiết bị và công nghệ tiên tiến đang định hình cuộc sống hàng ngày của chúng ta, từ đồng hồ thông minh đến máy bay không người lái.'},
    'zh': {'name': '现代小工具与技术', 'desc': '从智能手表到无人机，探索塑造我们日常生活的创新设备和技术。'}
}

def update_subject():
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
    
    payload = {"localized_data": loc_data}
    resp = requests.patch(f"{url_base}/rest/v1/subjects?id=eq.{subject_id}", headers=headers, json=payload)
    print(f"Subject update status: {resp.status_code}")

if __name__ == "__main__":
    update_subject()
