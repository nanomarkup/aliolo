import json
import os

lang_dir = "/home/vitaliinoga/aliolo/assets/lang"
sql_file = "/home/vitaliinoga/aliolo/incremental_translations.sql"

missing_keys = ["learn_mode_title", "test_mode_title", "no_cards_found_for_lang"]

with open(sql_file, "w", encoding="utf-8") as out:
    out.write("BEGIN;\n\n")
    for filename in os.listdir(lang_dir):
        if not filename.endswith(".json"): continue
        lang = filename.split(".")[0]
        filepath = os.path.join(lang_dir, filename)
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
            found_items = {k: v for k, v in data.items() if k in missing_keys}
            if found_items:
                out.write(f"-- {lang}\n")
                out.write("INSERT INTO ui_translations (key, lang, value) VALUES\n")
                rows = []
                for k, v in found_items.items():
                    k_safe = str(k).replace("'", "''")
                    v_safe = str(v).replace("'", "''")
                    rows.append(f"  ('{k_safe}', '{lang}', '{v_safe}')")
                out.write(",\n".join(rows))
                out.write("\nON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();\n\n")
    out.write("COMMIT;\n")
