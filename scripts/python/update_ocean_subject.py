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

subject_id = "2450ccd1-b439-4ed1-8280-30de3f41e400"

langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

# Dictionary of translations for "Types of Sea Animals" and a descriptive text
translations = {
    'en': {'name': 'Types of Sea Animals', 'desc': 'Explore the amazing diversity of life in our oceans, from the smallest fish to the largest whales.'},
    'ar': {'name': 'أنواع حيوانات البحر', 'desc': 'اكتشف التنوع المذهل للحياة في محيطاتنا، من أصغر الأسماك إلى أكبر الحيتان.'},
    'bg': {'name': 'Видове морски животни', 'desc': 'Изследвайте невероятното разнообразие от живот в нашите океани - от най-малките риби до най-големите китове.'},
    'cs': {'name': 'Druhy mořských živočichů', 'desc': 'Objevte úžasnou rozmanitost života v našich oceánech, od nejmenších ryb až po největší velryby.'},
    'da': {'name': 'Typer af havdyr', 'desc': 'Udforsk den fantastiske mangfoldighed af liv i vores oceaner, fra de mindste fisk til de største hvaler.'},
    'de': {'name': 'Arten von Meerestieren', 'desc': 'Entdecke die erstaunliche Vielfalt des Lebens in unseren Ozeanen, vom kleinsten Fisch bis zum größten Wal.'},
    'el': {'name': 'Είδη θαλάσσιων ζώων', 'desc': 'Εξερευνήστε την εκπληκτική ποικιλομορφία της ζωής στους ωκεανούς μας, από τα μικρότερα ψάρια μέχρι τις μεγαλύτερες φάλαινες.'},
    'es': {'name': 'Tipos de animales marinos', 'desc': 'Explora la increíble diversidad de vida en nuestros océanos, desde los peces más pequeños hasta las ballenas más grandes.'},
    'et': {'name': 'Mereloomade tüübid', 'desc': 'Avastage meie ookeanide elustiku hämmastav mitmekesisus, alates väikseimatest kaladest kuni suurimate vaaladeni.'},
    'fi': {'name': 'Merieläintyypit', 'desc': 'Tutustu valtameriemme elämän hämmästyttävään monimuotoisuuteen pienimmistä kaloista suurimpiin valaisiin.'},
    'fr': {'name': 'Types d\'animaux marins', 'desc': 'Explorez l\'incroyable diversité de la vie dans nos océans, des plus petits poissons aux plus grandes baleines.'},
    'ga': {'name': 'Cineálacha Ainmhithe Mara', 'desc': 'Déan iniúchadh ar an éagsúlacht iontach beatha inár n-aigéin, ó na héisc is lú go dtí na míolta móra is mó.'},
    'hi': {'name': 'समुद्री जानवरों के प्रकार', 'desc': 'सबसे छोटी मछलियों से लेकर सबसे बड़ी व्हेल तक, हमारे महासागरों में जीवन की अद्भुत विविधता का अन्वेषण करें।'},
    'hr': {'name': 'Vrste morskih životinja', 'desc': 'Istražite nevjerojatnu raznolikost života u našim oceanima, od najmanjih riba do najvećih kitova.'},
    'hu': {'name': 'Tengeri állatok típusai', 'desc': 'Fedezze fel óceánjaink életének lenyűgöző sokszínűségét, a legkisebb halaktól a legnagyobb bálnákig.'},
    'id': {'name': 'Jenis Hewan Laut', 'desc': 'Jelajahi keanekaragaman hayati yang menakjubkan di lautan kita, mulai dari ikan terkecil hingga paus terbesar.'},
    'it': {'name': 'Tipi di animali marini', 'desc': 'Esplora l\'incredibile diversità della vita nei nostri oceani, dai pesci più piccoli alle balene più grandi.'},
    'ja': {'name': '海洋動物の種類', 'desc': '最小の魚から最大のクジラまで、私たちの海に生息する生命の驚くべき多様性を探求してください。'},
    'ko': {'name': '해양 동물의 종류', 'desc': '가장 작은 물고기부터 가장 큰 고래까지, 우리 바다에 살고 있는 생명체의 놀라운 다양성을 탐험해 보세요.'},
    'lt': {'name': 'Jūros gyvūnų rūšys', 'desc': 'Atraskite nuostabią mūsų vandenynų gyvybės įvairovę – nuo mažiausių žuvų iki didžiausių banginių.'},
    'lv': {'name': 'Jūras dzīvnieku veidi', 'desc': 'Izpētiet mūsu okeānu dzīvības apbrīnojamo daudzveidību, sākot no mazākajām zivīm līdz lielākajiem vaļiem.'},
    'mt': {'name': 'Tipi ta\' annimali tal-baħar', 'desc': 'Esplora d-diversità aqwa tal-ħajja fl-oċeani tagħna, mill-iżgħar ħut sa l-akbar balieni.'},
    'nl': {'name': 'Soorten zeedieren', 'desc': 'Ontdek de verbazingwekkende diversiteit aan leven in onze oceanen, van de kleinste vissen tot de grootste walvissen.'},
    'pl': {'name': 'Rodzaje zwierząt morskich', 'desc': 'Poznaj niesamowitą różnorodność życia w naszych oceanach, od najmniejszych ryb po największe wieloryby.'},
    'pt': {'name': 'Tipos de animais marinhos', 'desc': 'Explore a incrível diversidade de vida em nossos oceanos, dos menores peixes às maiores baleias.'},
    'ro': {'name': 'Tipuri de animale marine', 'desc': 'Explorează diversitatea uimitoare a vieții în oceanele noastre, de la cei mai mici pești până la cele mai mari balene.'},
    'sk': {'name': 'Druhy morských živočíchov', 'desc': 'Objavte úžasnú rozmanitosť života v našich oceánoch, od najmenších rýb až po najväčšie veľryby.'},
    'sl': {'name': 'Vrste morskih živali', 'desc': 'Raziščite neverjetno raznolikost življenja v naših oceanih, od najmanjših rib do največjih kitov.'},
    'sv': {'name': 'Typer av havsdjur', 'desc': 'Utforska den fantastiska mångfalden av liv i våra hav, från de minsta fiskarna till de största valarna.'},
    'tl': {'name': 'Mga Uri ng Hayop sa Dagat', 'desc': 'Galugarin ang kamangha-manghang pagkakaiba-iba ng buhay sa ating mga karagatan, mula sa pinakamaliit na isda hanggang sa pinakamalaking balyena.'},
    'tr': {'name': 'Deniz Hayvanı Türleri', 'desc': 'En küçük balıktan en büyük balinaya kadar okyanuslarımızdaki inanılmaz yaşam çeşitliliğini keşfedin.'},
    'uk': {'name': 'Види морських тварин', 'desc': 'Досліджуйте дивовижне різноманіття життя в наших океанах — від найменших риб до найбільших китів.'},
    'vi': {'name': 'Các loại động vật biển', 'desc': 'Khám phá sự đa dạng đáng kinh ngạc của sự sống trong đại dương của chúng ta, từ những loài cá nhỏ nhất đến những loài cá voi lớn nhất.'},
    'zh': {'name': '海洋动物的种类', 'desc': '探索我们海洋中惊人的生命多样性，从最小的鱼类到最大的鲸鱼。'}
}

def update_subject():
    loc_data = {}
    for lang in langs:
        t = translations.get(lang, translations['en'])
        loc_data[lang] = {
            "name": t['name'],
            "description": t['desc']
        }
    
    # Global fallback
    loc_data["global"] = {
        "name": translations['en']['name'],
        "description": translations['en']['desc']
    }
    
    payload = {
        "localized_data": loc_data
    }
    
    resp = requests.patch(f"{url_base}/rest/v1/subjects?id=eq.{subject_id}", headers=headers, json=payload)
    print(f"Update status: {resp.status_code}")
    if resp.status_code >= 400:
        print(resp.text)

if __name__ == "__main__":
    update_subject()
