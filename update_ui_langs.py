
import re
import os

file_path = "/home/vitaliinoga/aliolo/generate_ui_langs.py"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

translations = {
    "en": ("Collection", "No subjects available", "Included Subjects"),
    "ar": ("مجموعة", "لا توجد مواضيع متاحة", "المواضيع المشمولة"),
    "bg": ("Колекция", "Няма налични предмети", "Включени предмети"),
    "cs": ("Kolekce", "Nejsou k dispozici žádné předměty", "Zahrnuté předměty"),
    "da": ("Samling", "Ingen emner tilgængelige", "Inkluderede emner"),
    "de": ("Kollektion", "Keine Fächer verfügbar", "Enthaltene Fächer"),
    "el": ("Συλλογή", "Δεν υπάρχουν διαθέсиμα θέματα", "Περιλαμβανόμενα θέματα"),
    "es": ("Colección", "No hay temas disponibles", "Temas incluidos"),
    "et": ("Kollektsioon", "Õppeaineid pole saadaval", "Kaasatud õppeained"),
    "fi": ("Kokoelma", "Aiheita ei ole saatavilla", "Sisältyvät aiheet"),
    "fr": ("Collection", "Aucun sujet disponible", "Sujets inclus"),
    "ga": ("Bailiúchán", "Níl aon ábhair ar fáil", "Ábhair san áireamh"),
    "hi": ("संग्रह", "कोई विषय उपलब्ध नहीं है", "शामिल विषय"),
    "hr": ("Kolekcija", "Nema dostupnih predmeta", "Uključeni predmeti"),
    "hu": ("Gyűjtemény", "Nem állnak rendelkezésre témák", "Tartalmazott témák"),
    "id": ("Koleksi", "Tidak ada subjek yang tersedia", "Subjek yang disertakan"),
    "it": ("Collezione", "Nessuna materia disponibile", "Materie incluse"),
    "ja": ("コレクション", "利用可能な科目はありません", "含まれる科目"),
    "ko": ("컬렉션", "사용 가능한 주제가 없습니다", "포함된 주제"),
    "lt": ("Kolekcija", "Temų nėra", "Įtrauktos temos"),
    "lv": ("Kolekcija", "Priekšmeti nav pieejami", "Iekļautie priekšmeti"),
    "mt": ("Kollezzjoni", "L-ebda suġġett disponibbli", "Suġġetti inklużi"),
    "nl": ("Collectie", "Geen onderwerpen beschikbaar", "Inbegrepen onderwerpen"),
    "pl": ("Kolekcja", "Brak dostępnych tematów", "Uwzględnione tematy"),
    "pt": ("Coleção", "Nenhum assunto disponível", "Assuntos incluídos"),
    "ro": ("Colecție", "Nu existã subiecte disponibile", "Subiecte incluse"),
    "sk": ("Kolekcia", "Nie sú k dispozícii žiadne predmety", "Zahrnuté předměty"),
    "sl": ("Zbirka", "Na voljo ni nobenega predmeta", "Vključeni predmeti"),
    "sv": ("Samling", "Inga ämnen tillgängliga", "Inkluderade ämnen"),
    "tl": ("Koleksyon", "Walang available na paksa", "Kasamang mga paksa"),
    "tr": ("Koleksiyon", "Mevcut konu yok", "Dahil edilen konular"),
    "uk": ("Колекція", "Немає доступних предметів", "Включені предмети"),
    "vi": ("Bộ sưu tập", "Không có chủ đề nào", "Các chủ đề bao gồm"),
    "zh": ("收藏", "无可用主题", "包含的主题"),
}

var_to_code = {
    "base_en": "en", "ar": "ar", "bg": "bg", "cs": "cs", "da": "da", "de": "de", "el": "el", "es": "es",
    "et": "et", "fi": "fi", "fr": "fr", "ga": "ga", "hi": "hi", "hr": "hr", "hu": "hu",
    "id": "id", "it": "it", "ja": "ja", "ko": "ko", "lt": "lt", "lv": "lv", "mt": "mt",
    "nl": "nl", "pl": "pl", "pt": "pt", "ro": "ro", "sk": "sk", "sl": "sl", "sv": "sv",
    "tl": "tl", "tr": "tr", "uk": "uk", "vi": "vi", "zh": "zh"
}

for var_name, code in var_to_code.items():
    # Use a safer regex to find the end of the dictionary
    # It should be the first } on a line by itself (ignoring whitespace) after the opening {
    pattern = rf"({var_name}\s*=\s*{{)(.*?)(\n\s*}})"
    match = re.search(pattern, content, re.DOTALL)
    
    if match:
        prefix = match.group(1)
        body = match.group(2)
        suffix = match.group(3)
        
        if "type_collection" not in body:
            col, no_sub, inc_sub = translations[code]
            body_trimmed = body.rstrip()
            if not body_trimmed.endswith(","):
                body = body_trimmed + ","
            else:
                body = body_trimmed
            
            new_keys = f'\n    "type_collection": "{col}",\n    "no_subjects_available": "{no_sub}",\n    "included_subjects": "{inc_sub}"'
            new_dict = prefix + body + new_keys + suffix
            content = content.replace(match.group(0), new_dict)
            print(f"Updated {var_name}")
        else:
            print(f"{var_name} already has the keys")
    else:
        print(f"Could not find dictionary for {var_name}")

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
print("Finished updating generate_ui_langs.py")
