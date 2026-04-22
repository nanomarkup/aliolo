import json
import os

data_str = """
{
  "en": {
    "no_localized_images": "No localized images"
  },
  "id": {
    "no_localized_images": "Tidak ada gambar yang dilokalkan"
  },
  "bg": {
    "no_localized_images": "Няма локализирани изображения"
  },
  "cs": {
    "no_localized_images": "Žádné lokalizované obrázky"
  },
  "da": {
    "no_localized_images": "Ingen lokaliserede billeder"
  },
  "de": {
    "no_localized_images": "Keine lokalisierten Bilder"
  },
  "et": {
    "no_localized_images": "Lokaliseeritud pilte pole"
  },
  "es": {
    "no_localized_images": "No hay imágenes localizadas"
  },
  "fr": {
    "no_localized_images": "Aucune image localisée"
  },
  "ga": {
    "no_localized_images": "Níl aon íomhánna logánta"
  },
  "hr": {
    "no_localized_images": "Nema lokaliziranih slika"
  },
  "it": {
    "no_localized_images": "Nessuna immagine localizzata"
  },
  "lv": {
    "no_localized_images": "Nav lokalizētu attēlu"
  },
  "lt": {
    "no_localized_images": "Nėra lokalizuotų vaizdų"
  },
  "hu": {
    "no_localized_images": "Nincsenek lokalizált képek"
  },
  "mt": {
    "no_localized_images": "L-ebda immaġni lokalizzata"
  },
  "nl": {
    "no_localized_images": "Geen gelokaliseerde afbeeldingen"
  },
  "pl": {
    "no_localized_images": "Brak zlokalizowanych obrazów"
  },
  "pt": {
    "no_localized_images": "Nenhuma imagem localizada"
  },
  "ro": {
    "no_localized_images": "Nu există imagini localizate"
  },
  "sk": {
    "no_localized_images": "Žiadne lokalizované obrázky"
  },
  "sl": {
    "no_localized_images": "Ni lokaliziranih slik"
  },
  "fi": {
    "no_localized_images": "Ei lokalisoituja kuvia"
  },
  "sv": {
    "no_localized_images": "Inga lokaliserade bilder"
  },
  "tl": {
    "no_localized_images": "Walang na-localize na mga larawan"
  },
  "vi": {
    "no_localized_images": "Không có hình ảnh được bản địa hóa"
  },
  "tr": {
    "no_localized_images": "Yerelleştirilmiş resim yok"
  },
  "el": {
    "no_localized_images": "Δεν υπάρχουν τοπικοποιημένες εικόνες"
  },
  "uk": {
    "no_localized_images": "Немає локалізованих зображень"
  },
  "ar": {
    "no_localized_images": "لا توجد صور محلية"
  },
  "hi": {
    "no_localized_images": "कोई स्थानीयकृत चित्र नहीं"
  },
  "zh": {
    "no_localized_images": "没有本地化图像"
  },
  "ja": {
    "no_localized_images": "ローカライズされた画像はありません"
  },
  "ko": {
    "no_localized_images": "현지화된 이미지 없음"
  }
}
"""

translations = json.loads(data_str)

sql_commands = []
for lang, keys in translations.items():
    for key, translation in keys.items():
        escaped_translation = translation.replace("'", "''")
        sql_commands.append(f"INSERT OR REPLACE INTO ui_translations (key, lang, value, updated_at) VALUES ('{key}', '{lang}', '{escaped_translation}', CURRENT_TIMESTAMP);")

full_sql = "\n".join(sql_commands)
with open("scripts/sql/update_no_loc_images_ui.sql", "w") as f:
    f.write(full_sql)

print("SQL script generated at scripts/sql/update_no_loc_images_ui.sql")
