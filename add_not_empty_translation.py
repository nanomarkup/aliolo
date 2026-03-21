import os
import json

lang_dir = "assets/lang"

translations = {
    "en": {"folder_not_empty_msg": "Cannot delete: folder is not empty."},
    "uk": {"folder_not_empty_msg": "Неможливо видалити: папка не порожня."},
    "es": {"folder_not_empty_msg": "No se puede eliminar: la carpeta no está vacía."},
    "fr": {"folder_not_empty_msg": "Impossible de supprimer : le dossier n'est pas vide."},
    "de": {"folder_not_empty_msg": "Löschen nicht möglich: Ordner ist nicht leer."},
    "it": {"folder_not_empty_msg": "Impossibile eliminare: la cartella non è vuota."},
    "pt": {"folder_not_empty_msg": "Não é possível excluir: a pasta não está vazia."},
    "zh": {"folder_not_empty_msg": "无法删除：文件夹非空。"},
    "ja": {"folder_not_empty_msg": "削除できません：フォルダが空ではありません。"},
    "ko": {"folder_not_empty_msg": "삭제할 수 없음: 폴더가 비어있지 않습니다."},
    "ar": {"folder_not_empty_msg": "لا يمكن الحذف: المجلد ليس فارغًا."},
    "hi": {"folder_not_empty_msg": "हटा नहीं सकते: फ़ोल्डर खाली नहीं है।"},
    "tr": {"folder_not_empty_msg": "Silinemiyor: klasör boş değil."},
    "nl": {"folder_not_empty_msg": "Kan niet verwijderen: map is niet leeg."},
    "pl": {"folder_not_empty_msg": "Nie można usunąć: folder nie jest pusty."},
    "sv": {"folder_not_empty_msg": "Kan inte ta bort: mappen är inte tom."},
    "fi": {"folder_not_empty_msg": "Ei voi poistaa: kansio ei ole tyhjä."},
    "da": {"folder_not_empty_msg": "Kan ikke slette: mappen er ikke tom."},
    "cs": {"folder_not_empty_msg": "Nelze smazat: složka není prázdná."},
    "sk": {"folder_not_empty_msg": "Nemožno vymazať: priečinok nie je prázdny."},
    "hu": {"folder_not_empty_msg": "Nem törölhető: a mappa nem üres."},
    "ro": {"folder_not_empty_msg": "Nu se poate șterge: folderul nu este gol."},
    "bg": {"folder_not_empty_msg": "Не може да се изтрие: папката не е празна."},
    "el": {"folder_not_empty_msg": "Δεν είναι δυνατή η διαγραφή: ο φάκελος δεν είναι άδειος."},
    "hr": {"folder_not_empty_msg": "Nije moguće obrisati: mapa nije prazna."},
    "sl": {"folder_not_empty_msg": "Ni mogoče izbrisati: mapa ni prazna."},
    "et": {"folder_not_empty_msg": "Ei saa kustutada: kaust pole tühi."},
    "lv": {"folder_not_empty_msg": "Nevar dzēst: mape nav tukša."},
    "lt": {"folder_not_empty_msg": "Negalima ištrinti: aplankas nėra tuščias."},
    "mt": {"folder_not_empty_msg": "Ma jistax jitħassar: il-folder mhuwiex vojt."},
    "ga": {"folder_not_empty_msg": "Ní féidir scriosadh: níl an fillteán folamh."},
    "vi": {"folder_not_empty_msg": "Không thể xóa: thư mục không trống."},
    "id": {"folder_not_empty_msg": "Tidak dapat menghapus: folder tidak kosong."},
    "tl": {"folder_not_empty_msg": "Hindi ma-delete: hindi walang laman ang folder."}
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
