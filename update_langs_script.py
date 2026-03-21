
import os

mapping = {
    "Add Folder": "Edit Folder",
    "إضافة مجلد": "تعديل المجلد",
    "Ordner hinzufügen": "Ordner bearbeiten",
    "Προσθήκη φακέλου": "Επεξεργασία φακέλου",
    "Añadir carpeta": "Editar carpeta",
    "Ajouter un dossier": "Modifier le dossier",
    "फ़ोルダー जोड़ें": "फ़ोルダー संपादित करें",
    "Tambah Folder": "Ubah Folder",
    "Aggiungi cartella": "Modifica cartella",
    "フォルダを追加": "フォルダを編集",
    "폴더 추가": "폴더 편집",
    "Добавяне на папка": "Редактиране на папка",
    "Přidat složku": "Upravit složku",
    "Tilføj mappe": "Rediger mappe",
    "Lisa kaust": "Muuda kausta",
    "Lisää kansio": "Muokkaa kansiota",
    "Cuir fillteán leis": "Cuir fillteán in eagar",
    "Dodaj mapu": "Uredi mapu",
    "Mappa hozzáadása": "Mappa szerkesztése",
    "Pridėti aplanką": "Redaguoti aplanką",
    "Pievienot mapi": "Rediģēt mapi",
    "Żid folder": "Editja l-folder",
    "Adaugă folder": "Editează folder",
    "Pridať priečinok": "Upraviť priečinok",
    "Dodaj mapo": "Uredi mapo",
    "Lägg till mapp": "Redigera mapp",
    "Map toevoegen": "Map bewerken",
    "Dodaj folder": "Edytuj folder",
    "Adicionar pasta": "Editar pasta",
    "Magdagdag ng folder": "I-edit ang folder",
    "Klasör ekle": "Klasörü düzenle",
    "Додати папку": "Редагувати папку",
    "Thêm thư mục": "Chỉnh sửa thư mục",
    "添加文件夹": "编辑文件夹"
}

file_path = "/home/vitaliinoga/aliolo/generate_ui_langs.py"

with open(file_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

new_lines = []
count = 0
for line in lines:
    new_lines.append(line)
    if '"add_folder":' in line:
        # Extract the value
        start = line.find('": "') + 4
        end = line.rfind('"')
        val = line[start:end]
        if val in mapping:
            edit_val = mapping[val]
            # Maintain same indentation
            indent = line[:line.find('"')]
            comma = "," if line.strip().endswith(",") else ""
            
            # Check if current line has a comma at the end, if not add it to the previous line if it was the last element
            if not line.strip().endswith(",") and not line.strip().endswith("{"):
                # If the line doesn't end with a comma, we should add one to the add_folder line
                # But wait, in the dictionaries, the last item usually doesn't have a comma.
                # If we insert edit_folder after add_folder, add_folder MUST have a comma.
                last_line = new_lines.pop()
                new_lines.append(last_line.rstrip().rstrip(",") + ",\n")
                new_lines.append(f'{indent}"edit_folder": "{edit_val}"\n')
            else:
                new_lines.append(f'{indent}"edit_folder": "{edit_val}",\n')
            count += 1

with open(file_path, "w", encoding="utf-8") as f:
    f.writelines(new_lines)

print(f"Updated {count} dictionaries.")
