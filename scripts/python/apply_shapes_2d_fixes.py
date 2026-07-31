import json
import subprocess
import csv
import sys
from pathlib import Path

DB_NAME = "aliolo-db"
REPORT_PATH = "aliolo/scripts/.tmp/shapes_2d_quality_report.csv"
SHAPES_2D_SID = "031f918e-6afa-469b-97bc-48a65e565237"

def run_wrangler_query(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return None
    try:
        return json.loads(res.stdout)
    except:
        return None

def run_wrangler_update(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode == 0

def main():
    if not Path(REPORT_PATH).exists():
        print(f"Report not found: {REPORT_PATH}")
        return

    with open(REPORT_PATH, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    print(f"Applying selected translation fixes for Shapes 2D...")

    updates = {}
    for row in rows:
        cid = row['card_id']
        if cid not in updates: updates[cid] = []
        updates[cid].append(row)

    for cid, fixes in updates.items():
        if cid == "SUBJECT":
            # Subject name fixes usually not needed as they were already high quality
            continue
        
        # We only want to fix specific cases:
        # 1. Gaelic (ga) was often missing (equal to English)
        # 2. Critical mismatches in answers
        
        relevant_fixes = []
        for fix in fixes:
            # Fix Gaelic missing translations
            if fix['locale'] == 'ga' and fix['current_text'] == fix['global_text']:
                relevant_fixes.append(fix)
            # Fix Diamond confusion (Gem vs Shape)
            elif fix['field'] == 'answer' and fix['global_text'] == 'Diamond' and fix['translated_text'].lower() in ['romb', 'rombo', 'rombas', 'ruit', 'vinoneliö', 'kosočtverec']:
                # The current text was often 'Diamond' or 'Gemstone' translation
                # But here the translator often suggested 'Diamond' (gem) instead of 'Rhombus'
                # Actually, in most languages 'Diamond' as a shape IS 'Rhomb'.
                # Let's check a few.
                pass 
            # Fix 'What shape is this?' phrasings if current is very different
            elif fix['field'] == 'prompt' and len(fix['current_text']) < 3: # empty or too short
                 relevant_fixes.append(fix)

        if not relevant_fixes:
            continue

        print(f"Updating Card {cid}...")
        fields_to_fix = list(set([f['field'] for f in relevant_fixes]))
        field_map = {"answer": "answers", "prompt": "prompts", "display_text": "display_texts"}
        json_fields = [field_map[f] for f in fields_to_fix]
        
        fetch_sql = f"SELECT {', '.join(json_fields)} FROM cards WHERE id = '{cid}'"
        res = run_wrangler_query(fetch_sql)
        if not res or not res[0].get('results'): continue
        
        current_data = res[0]['results'][0]
        update_sets = []
        
        for f_base in fields_to_fix:
            f_json = field_map[f_base]
            local_map = json.loads(current_data[f_json] or '{}')
            
            for fix in [f for f in relevant_fixes if f['field'] == f_base]:
                local_map[fix['locale']] = fix['translated_text']
            
            escaped_val = json.dumps(local_map, ensure_ascii=False).replace("'", "''")
            update_sets.append(f"{f_json} = '{escaped_val}'")
        
        update_sql = f"UPDATE cards SET {', '.join(update_sets)}, updated_at = CURRENT_TIMESTAMP WHERE id = '{cid}'"
        if run_wrangler_update(update_sql):
            print(f"  Successfully updated card {cid}.")

    print("\nApplied selected fixes successfully.")

if __name__ == "__main__":
    main()
