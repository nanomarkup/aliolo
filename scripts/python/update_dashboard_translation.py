import os
import json

lang_dir = "assets/lang"

translations = {
    "en": {"filter_dashboard": "Dashboard"},
    "uk": {"filter_dashboard": "Дашборд"},
    "es": {"filter_dashboard": "Tablero"},
    "fr": {"filter_dashboard": "Tableau de bord"},
    "de": {"filter_dashboard": "Dashboard"},
    "it": {"filter_dashboard": "Dashboard"},
    "pt": {"filter_dashboard": "Painel"},
    "zh": {"filter_dashboard": "仪表板"},
    "ja": {"filter_dashboard": "ダッシュボード"},
    "ko": {"filter_dashboard": "대시보드"},
    "ar": {"filter_dashboard": "لوحة القيادة"},
    "hi": {"filter_dashboard": "डैशबोर्ड"},
    "tr": {"filter_dashboard": "Kontrol Paneli"},
    "nl": {"filter_dashboard": "Dashboard"},
    "pl": {"filter_dashboard": "Pulpit"},
    "sv": {"filter_dashboard": "Instrumentpanel"},
    "fi": {"filter_dashboard": "Hallintapaneeli"},
    "da": {"filter_dashboard": "Kontrolpanel"},
    "cs": {"filter_dashboard": "Nástěnka"},
    "sk": {"filter_dashboard": "Nástenka"},
    "hu": {"filter_dashboard": "Vezérlőpult"},
    "ro": {"filter_dashboard": "Tablou de bord"},
    "bg": {"filter_dashboard": "Табло"},
    "el": {"filter_dashboard": "Πίνακας ελέγχου"},
    "hr": {"filter_dashboard": "Nadzorna ploča"},
    "sl": {"filter_dashboard": "Nadzorna plošča"},
    "et": {"filter_dashboard": "Töölaud"},
    "lv": {"filter_dashboard": "Informācijas panelis"},
    "lt": {"filter_dashboard": "Valdymo skydas"},
    "mt": {"filter_dashboard": "Dashboard"},
    "ga": {"filter_dashboard": "Painéal"},
    "vi": {"filter_dashboard": "Bảng điều khiển"},
    "id": {"filter_dashboard": "Dasbor"},
    "tl": {"filter_dashboard": "Dashboard"}
}

for filename in os.listdir(lang_dir):
    if filename.endswith(".json"):
        lang = filename.split(".")[0]
        filepath = os.path.join(lang_dir, filename)
        
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
            
        updated = False
        # Add filter_dashboard
        val = translations.get(lang, translations["en"])["filter_dashboard"]
        if "filter_dashboard" not in data or data["filter_dashboard"] != val:
            data["filter_dashboard"] = val
            updated = True
            
        # Remove filter_all
        if "filter_all" in data:
            del data["filter_all"]
            updated = True
            
        # Optional: Remove filter_favorites if no longer needed, but let's keep it for now just in case
        
        if updated:
            with open(filepath, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            print(f"Updated {filename}")
        else:
            print(f"No changes for {filename}")
