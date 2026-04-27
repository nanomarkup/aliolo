import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_IDS = ['68232807-b9cd-4cff-872c-c398444f85e2', 'bc354f43-f9be-42a9-a7bc-ac400bd5e310']
OUTPUT_SQL = Path("scripts/.tmp/subject_metadata_fixes.sql")

def run_wrangler(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return []
    try:
        return json.loads(res.stdout)[0]["results"]
    except:
        return []

def get_localized_num(val, locale):
    # Mapping for numbers 0 and 10 in metadata context
    maps = {
        'ar': {"0": "٠", "10": "١٠"},
        'hi': {"0": "०", "10": "१०"},
        'ja': {"0": "〇", "10": "十"},
        'zh': {"0": "〇", "10": "十"},
        'ko': {"0": "영", "10": "십"}
    }
    return maps.get(locale, {}).get(val, val)

def main():
    print("Fetching subjects from DB...")
    ids_str = "', '".join(SUBJECT_IDS)
    subjects = run_wrangler(f"SELECT id, names, descriptions FROM subjects WHERE id IN ('{ids_str}')")
    
    if not subjects:
        print("No subjects found.")
        return

    sql_statements = []
    
    for subj in subjects:
        sid = subj['id']
        names = json.loads(subj['names'] or '{}')
        descriptions = json.loads(subj['descriptions'] or '{}')
        
        target_locales = ['ar', 'hi', 'ja', 'zh', 'ko']
        
        for locale in target_locales:
            l_0 = get_localized_num("0", locale)
            l_10 = get_localized_num("10", locale)
            
            # Update name (e.g. "Counting 0-10")
            if locale in names:
                # Replace 10 first to avoid partial 0 replacement if 10 is represented as 1+0
                names[locale] = names[locale].replace("10", l_10).replace("0", l_0)
                
            # Update description (e.g. "counting from 0 to 10")
            if locale in descriptions:
                # Use a more robust replacement strategy for numbers in text
                descriptions[locale] = descriptions[locale].replace("10", l_10).replace("0", l_0)

        names_json = json.dumps(names, ensure_ascii=False).replace("'", "''")
        desc_json = json.dumps(descriptions, ensure_ascii=False).replace("'", "''")
        
        sql = f"UPDATE subjects SET names = '{names_json}', descriptions = '{desc_json}', updated_at = CURRENT_TIMESTAMP WHERE id = '{sid}';"
        sql_statements.append(sql)

    with open(OUTPUT_SQL, mode='w', encoding='utf-8') as f:
        f.write("-- Localizing digits in Subject Names and Descriptions (Improved)\n")
        f.write("\n".join(sql_statements))
        f.write("\n")

    print(f"Generated {len(sql_statements)} SQL update statements.")
    print(f"SQL file: {OUTPUT_SQL}")

if __name__ == "__main__":
    main()
