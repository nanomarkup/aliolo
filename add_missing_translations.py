import os
import json

lang_dir = "assets/lang"

translations = {
    "en": {"folder": "Folder", "no_folder": "No Folder (Root)", "edit_collection": "Edit Collection"},
    "uk": {"folder": "Папка", "no_folder": "Немає папки (Коренева)", "edit_collection": "Редагувати колекцію"},
    "es": {"folder": "Carpeta", "no_folder": "Sin carpeta (Raíz)", "edit_collection": "Editar colección"},
    "fr": {"folder": "Dossier", "no_folder": "Aucun dossier (Racine)", "edit_collection": "Modifier la collection"},
    "de": {"folder": "Ordner", "no_folder": "Kein Ordner (Stamm)", "edit_collection": "Kollektion bearbeiten"},
    "it": {"folder": "Cartella", "no_folder": "Nessuna cartella (Radice)", "edit_collection": "Modifica collezione"},
    "pt": {"folder": "Pasta", "no_folder": "Sem pasta (Raiz)", "edit_collection": "Editar coleção"},
    "zh": {"folder": "文件夹", "no_folder": "无文件夹 (根目录)", "edit_collection": "编辑收藏"},
    "ja": {"folder": "フォルダ", "no_folder": "フォルダなし (ルート)", "edit_collection": "コレクションを編集"},
    "ko": {"folder": "폴더", "no_folder": "폴더 없음 (루트)", "edit_collection": "컬렉션 편집"},
    "ar": {"folder": "مجلد", "no_folder": "لا يوجد مجلد (الجذر)", "edit_collection": "تعديل المجموعة"},
    "hi": {"folder": "फ़ोल्डर", "no_folder": "कोई फ़ोल्डर नहीं (रूट)", "edit_collection": "संग्रह संपादित करें"},
    "tr": {"folder": "Klasör", "no_folder": "Klasör Yok (Kök)", "edit_collection": "Koleksiyonu Düzenle"},
    "nl": {"folder": "Map", "no_folder": "Geen map (Root)", "edit_collection": "Collectie bewerken"},
    "pl": {"folder": "Folder", "no_folder": "Brak folderu (Katalog główny)", "edit_collection": "Edytuj kolekcję"},
    "sv": {"folder": "Mapp", "no_folder": "Ingen mapp (Rot)", "edit_collection": "Redigera samling"},
    "fi": {"folder": "Kansio", "no_folder": "Ei kansiota (Juuri)", "edit_collection": "Muokkaa kokoelmaa"},
    "da": {"folder": "Mappe", "no_folder": "Ingen mappe (Rod)", "edit_collection": "Rediger samling"},
    "cs": {"folder": "Složka", "no_folder": "Žádná složka (Kořen)", "edit_collection": "Upravit kolekci"},
    "sk": {"folder": "Priečinok", "no_folder": "Žiadny priečinok (Koreň)", "edit_collection": "Upraviť kolekciu"},
    "hu": {"folder": "Mappa", "no_folder": "Nincs mappa (Gyökér)", "edit_collection": "Gyűjtemény szerkesztése"},
    "ro": {"folder": "Folder", "no_folder": "Niciun folder (Rădăcină)", "edit_collection": "Editați colecția"},
    "bg": {"folder": "Папка", "no_folder": "Няма папка (Основна)", "edit_collection": "Редактиране на колекция"},
    "el": {"folder": "Φάκελος", "no_folder": "Κανένας φάκελος (Ρίζα)", "edit_collection": "Επεξεργασία συλλογής"},
    "hr": {"folder": "Mapa", "no_folder": "Nema mape (Korijen)", "edit_collection": "Uredi kolekciju"},
    "sl": {"folder": "Mapa", "no_folder": "Ni mape (Koren)", "edit_collection": "Uredi zbirko"},
    "et": {"folder": "Kaust", "no_folder": "Kaust puudub (Juur)", "edit_collection": "Muuda kollektsiooni"},
    "lv": {"folder": "Mape", "no_folder": "Nav mapes (Sakne)", "edit_collection": "Rediģēt kolekciju"},
    "lt": {"folder": "Aplankas", "no_folder": "Nėra aplanko (Šaknis)", "edit_collection": "Redaguoti kolekciją"},
    "mt": {"folder": "Folder", "no_folder": "L-ebda folder (Għerq)", "edit_collection": "Editja kollezzjoni"},
    "ga": {"folder": "Fillteán", "no_folder": "Níl aon fhillteán (Fréamh)", "edit_collection": "Cuir bailiúchán in eagar"},
    "vi": {"folder": "Thư mục", "no_folder": "Không có thư mục (Gốc)", "edit_collection": "Chỉnh sửa bộ sưu tập"},
    "id": {"folder": "Folder", "no_folder": "Tidak ada folder (Root)", "edit_collection": "Ubah Koleksi"},
    "tl": {"folder": "Folder", "no_folder": "Walang folder (Root)", "edit_collection": "I-edit ang koleksyon"}
}

for filename in os.listdir(lang_dir):
    if filename.endswith(".json"):
        lang = filename.split(".")[0]
        filepath = os.path.join(lang_dir, filename)
        
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
            
        updated = False
        if lang in translations:
            for key, val in translations[lang].items():
                if key not in data or data[key] != val:
                    data[key] = val
                    updated = True
        else:
            # Fallback to English
            for key, val in translations["en"].items():
                if key not in data:
                    data[key] = val
                    updated = True
                    
        if updated:
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"Updated {filename}")
        else:
            print(f"No changes for {filename}")
