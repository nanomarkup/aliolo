import json
import os

lang_dir = "/home/vitaliinoga/aliolo/assets/lang"
sql_file = "/home/vitaliinoga/aliolo/translations_insert.sql"

print("Generating SQL...")

with open(sql_file, "w", encoding="utf-8") as out:
    out.write("BEGIN;\n\n")
    
    for filename in os.listdir(lang_dir):
        if not filename.endswith(".json"):
            continue
            
        lang = filename.split(".")[0]
        filepath = os.path.join(lang_dir, filename)
        
        with open(filepath, "r", encoding="utf-8") as f:
            try:
                data = json.load(f)
                
                # Batch inserts to avoid massive single statements
                batch_size = 100
                items = list(data.items())
                
                for i in range(0, len(items), batch_size):
                    batch = items[i:i+batch_size]
                    out.write("INSERT INTO ui_translations (key, lang, value) VALUES\n")
                    
                    values = []
                    for k, v in batch:
                        # Escape single quotes in values
                        safe_val = str(v).replace("'", "''")
                        safe_key = str(k).replace("'", "''")
                        values.append(f"  ('{safe_key}', '{lang}', '{safe_val}')")
                        
                    out.write(",\n".join(values))
                    out.write("\nON CONFLICT (key, lang) DO UPDATE SET value = EXCLUDED.value, updated_at = NOW();\n\n")
                    
            except Exception as e:
                print(f"Error processing {filename}: {e}")
                
    out.write("COMMIT;\n")

print(f"Done! SQL saved to {sql_file}")
