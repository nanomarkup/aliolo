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

subject_id = "0b84447d-3af3-4509-bdf6-c4e7fe822cc7"
langs = ['ar', 'bg', 'cs', 'da', 'de', 'el', 'en', 'es', 'et', 'fi', 'fr', 'ga', 'hi', 'hr', 'hu', 'id', 'it', 'ja', 'ko', 'lt', 'lv', 'mt', 'nl', 'pl', 'pt', 'ro', 'sk', 'sl', 'sv', 'tl', 'tr', 'uk', 'vi', 'zh']

# Accurate description: "Learn about 140 different colors and their HEX codes, from primary shades to rare tints."
translations = {
    'en': "Learn about 140 different colors and their HEX codes, from primary shades to rare tints.",
    'ar': "تعرف على 140 لونًا مختلفًا وأكواد HEX الخاصة بها، من الظلال الأساسية إلى الصبغات النادرة.",
    'bg': "Научете за 140 различни цвята и техните HEX кодове, от основни нюанси до редки тонове.",
    'cs': "Dozvíte se o 140 různých barvách a jejich HEX kódech, od základních odstínů až po vzácné tóny.",
    'da': "Lær om 140 forskellige farver og deres HEX-koder, fra primære nuancer til sjældne farvetoner.",
    'de': "Lerne 140 verschiedene Farben und ihre HEX-Codes kennen, von Primärfarben bis hin zu seltenen Nuancen.",
    'el': "Μάθετε για 140 διαφορετικά χρώματα και τους κωδικούς τους HEX, από βασικές αποχρώσεις έως σπάνιους τόνους.",
    'es': "Aprende sobre 140 colores diferentes y sus códigos HEX, desde tonos primarios hasta tintes raros.",
    'et': "Õpi tundma 140 erinevat värvi ja nende HEX-koode, alates põhivärvidest kuni haruldaste varjunditeni.",
    'fi': "Opi 140 eri väristä ja niiden HEX-koodeista, perussävyistä harvinaisiin vivahteisiin.",
    'fr': "Découvrez 140 couleurs différentes et leurs codes HEX, des teintes primaires aux nuances rares.",
    'ga': "Foghlaim faoi 140 dath difriúil agus a gcuid cóid HEX, ó scáileanna príomhúla go tintí neamhchoitianta.",
    'hi': "140 विभिन्न रंगों और उनके HEX कोड के बारे में जानें, प्राथमिक रंगों से लेकर दुर्लभ रंगों तक।",
    'hr': "Naučite o 140 različitih boja i njihovim HEX kodovima, od primarnih nijansi do rijetkih tonova.",
    'hu': "Ismerj meg 140 különböző színt és azok HEX-kódjait, az elsődleges árnyalatoktól a ritka tónusokig.",
    'id': "Pelajari tentang 140 warna berbeda dan kode HEX-nya, mulai dari nuansa primer hingga rona langka.",
    'it': "Scopri 140 colori diversi e i loro codici HEX, dalle tonalità primarie alle sfumature rare.",
    'ja': "原色から珍しい色合いまで、140 種類の異なる色とその HEX コードについて学びましょう。",
    'ko': "기본 색상부터 희귀한 색조까지 140가지의 다양한 색상과 HEX 코드에 대해 알아보세요.",
    'lt': "Sužinokite apie 140 skirtingų spalvų ir jų HEX kodus – nuo pagrindinių atspalvių iki retų tonų.",
    'lv': "Uzziniet par 140 dažādām krāsām un to HEX kodiem, sākot no pamata toņiem līdz retām niansēm.",
    'mt': "Tgħallem dwar 140 kulur differenti u l-kodiċijiet HEX tagħhom, minn sfumaturi primarji sa kuluri rari.",
    'nl': "Leer meer over 140 verschillende kleuren und hun HEX-codes, van primaire tinten tot zeldzame nuances.",
    'pl': "Poznaj 140 różnych kolorów i ich kody HEX, od odcieni podstawowych po rzadkie barwy.",
    'pt': "Aprenda sobre 140 cores diferentes e seus códigos HEX, de tons primários a nuances raras.",
    'ro': "Aflați despre 140 de culori diferite și codurile lor HEX, de la nuanțe primare la tonuri rare.",
    'sk': "Dozviete sa o 140 rôznych farbách a ich HEX kódoch, od základných odtieňov až po vzácne tóny.",
    'sl': "Spoznajte 140 različnih barv in njihove HEX kode, od primarnih odtenkov do redkih barvnih tonov.",
    'sv': "Lär dig om 140 olika färger och deras HEX-koder, från primärfärger till sällsynta nyanser.",
    'tl': "Alamin ang tungkol sa 140 iba't ibang kulay at ang kanilang mga HEX code, mula sa mga pangunahing shade hanggang sa mga bihirang tint.",
    'tr': "Ana renklerden nadir tonlara kadar 140 farklı rengi ve HEX kodlarını öğrenin.",
    'uk': "Дізнайтеся про 140 різних кольорів та їхні HEX-коди: від основних відтінків до рідкісних тонів.",
    'vi': "Tìm hiểu về 140 màu sắc khác nhau và mã HEX của chúng, từ các tông màu cơ bản đến các sắc thái hiếm gặp.",
    'zh': "了解 140 种不同的颜色及其 HEX 代码，从基本色调到稀有的色度。"
}

def update_colors_desc():
    # 1. Fetch current data to preserve names
    resp = requests.get(f"{url_base}/rest/v1/subjects?id=eq.{subject_id}&select=localized_data", headers=headers)
    data = resp.json()[0]['localized_data']
    
    # 2. Update descriptions
    for lang in langs:
        if lang in data:
            data[lang]['description'] = translations.get(lang, translations['en'])
        else:
            # If lang is missing in data, we create it but we'd need the name... 
            # The current card set has all 34 langs, so names should exist.
            pass
            
    # Update global
    data['global']['description'] = translations['en']
    
    # 3. Push update
    up_resp = requests.patch(f"{url_base}/rest/v1/subjects?id=eq.{subject_id}", headers=headers, json={"localized_data": data})
    print(f"Update status: {up_resp.status_code}")

if __name__ == "__main__":
    update_colors_desc()
