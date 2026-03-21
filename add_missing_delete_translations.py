import os
import json

lang_dir = "assets/lang"

translations = {
    "en": {"delete_collection": "Delete Collection", "delete_collection_confirm": "Are you sure you want to delete this collection?"},
    "uk": {"delete_collection": "Видалити колекцію", "delete_collection_confirm": "Ви впевнені, що хочете видалити цю колекцію?"},
    "es": {"delete_collection": "Eliminar colección", "delete_collection_confirm": "¿Seguro que quieres eliminar esta colección?"},
    "fr": {"delete_collection": "Supprimer la collection", "delete_collection_confirm": "Êtes-vous sûr de vouloir supprimer cette collection ?"},
    "de": {"delete_collection": "Kollektion löschen", "delete_collection_confirm": "Möchten Sie diese Kollektion wirklich löschen?"},
    "it": {"delete_collection": "Elimina collezione", "delete_collection_confirm": "Sei sicuro di voler eliminare questa collezione?"},
    "pt": {"delete_collection": "Excluir coleção", "delete_collection_confirm": "Tem certeza que deseja excluir esta coleção?"},
    "zh": {"delete_collection": "删除收藏", "delete_collection_confirm": "你确定要删除这个收藏吗？"},
    "ja": {"delete_collection": "コレクションを削除", "delete_collection_confirm": "このコレクションを削除してもよろしいですか？"},
    "ko": {"delete_collection": "컬렉션 삭제", "delete_collection_confirm": "이 컬렉션을 삭제하시겠습니까?"},
    "ar": {"delete_collection": "حذف المجموعة", "delete_collection_confirm": "هل أنت متأكد أنك تريد حذف هذه المجموعة؟"},
    "hi": {"delete_collection": "संग्रह हटाएं", "delete_collection_confirm": "क्या आप वाकई इस संग्रह को हटाना चाहते हैं?"},
    "tr": {"delete_collection": "Koleksiyonu Sil", "delete_collection_confirm": "Bu koleksiyonu silmek istediğinizden emin misiniz?"},
    "nl": {"delete_collection": "Collectie verwijderen", "delete_collection_confirm": "Weet je zeker dat je deze collectie wilt verwijderen?"},
    "pl": {"delete_collection": "Usuń kolekcję", "delete_collection_confirm": "Czy na pewno chcesz usunąć tę kolekcję?"},
    "sv": {"delete_collection": "Ta bort samling", "delete_collection_confirm": "Är du säker på att du vill ta bort denna samling?"},
    "fi": {"delete_collection": "Poista kokoelma", "delete_collection_confirm": "Haluatko varmasti poistaa tämän kokoelman?"},
    "da": {"delete_collection": "Slet samling", "delete_collection_confirm": "Er du sikker på, at du vil slette denne samling?"},
    "cs": {"delete_collection": "Smazat kolekci", "delete_collection_confirm": "Opravdu chcete tuto kolekci smazat?"},
    "sk": {"delete_collection": "Vymazať kolekciu", "delete_collection_confirm": "Naozaj chcete vymazať túto kolekciu?"},
    "hu": {"delete_collection": "Gyűjtemény törlése", "delete_collection_confirm": "Biztosan törölni szeretné ezt a gyűjteményt?"},
    "ro": {"delete_collection": "Ștergeți colecția", "delete_collection_confirm": "Sigur doriți să ștergeți această colecție?"},
    "bg": {"delete_collection": "Изтриване на колекция", "delete_collection_confirm": "Сигурни ли сте, че искате да изтриете тази колекция?"},
    "el": {"delete_collection": "Διαγραφή συλλογής", "delete_collection_confirm": "Είστε σίγουροι ότι θέλετε να διαγράψετε αυτήν τη συλλογή;"},
    "hr": {"delete_collection": "Obriši kolekciju", "delete_collection_confirm": "Jeste li sigurni da želite obrisati ovu kolekciju?"},
    "sl": {"delete_collection": "Izbriši zbirko", "delete_collection_confirm": "Ste prepričani, da želite izbrisati to zbirko?"},
    "et": {"delete_collection": "Kustuta kollektsioon", "delete_collection_confirm": "Kas olete kindel, et soovite selle kollektsiooni kustutada?"},
    "lv": {"delete_collection": "Dzēst kolekciju", "delete_collection_confirm": "Vai tiešām vēlaties dzēst šo kolekciju?"},
    "lt": {"delete_collection": "Ištrinti kolekciją", "delete_collection_confirm": "Ar tikrai norite ištrinti šią kolekciją?"},
    "mt": {"delete_collection": "Ħassar kollezzjoni", "delete_collection_confirm": "Inti żgur li trid tħassar din il-kollezzjoni?"},
    "ga": {"delete_collection": "Scrios bailiúchán", "delete_collection_confirm": "An bhfuil tú cinnte go dteastaíonn uait an bailiúchán seo a scriosadh?"},
    "vi": {"delete_collection": "Xóa bộ sưu tập", "delete_collection_confirm": "Bạn có chắc chắn muốn xóa bộ sưu tập này không?"},
    "id": {"delete_collection": "Hapus Koleksi", "delete_collection_confirm": "Apakah Anda yakin ingin menghapus koleksi ini?"},
    "tl": {"delete_collection": "Tanggalin ang koleksyon", "delete_collection_confirm": "Sigurado ka bang gusto mong tanggalin ang koleksyong ito?"}
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
