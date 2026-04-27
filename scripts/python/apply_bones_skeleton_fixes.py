import json
import subprocess
import csv
import sys
from pathlib import Path

DB_NAME = "aliolo-db"
REPORT_PATH = "aliolo/scripts/.tmp/bones_skeleton_quality_report.csv"
BONES_SID = "25fff407-d9d1-4e29-a176-41ce01157c63"

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

    print(f"Applying {len(rows)} translation fixes...")

    updates = {}
    for row in rows:
        cid = row['card_id']
        if cid not in updates: updates[cid] = []
        updates[cid].append(row)

    for cid, fixes in updates.items():
        if cid == "SUBJECT":
            print(f"Updating Subject {BONES_SID} names...")
            res = run_wrangler_query(f"SELECT names FROM subjects WHERE id = '{BONES_SID}'")
            if not res or not res[0].get('results'): continue
            
            names = json.loads(res[0]['results'][0]['names'] or '{}')
            for fix in fixes:
                names[fix['locale']] = fix['translated_text']
            
            escaped_json = json.dumps(names, ensure_ascii=False).replace("'", "''")
            run_wrangler_update(f"UPDATE subjects SET names = '{escaped_json}', updated_at = CURRENT_TIMESTAMP WHERE id = '{BONES_SID}'")
            print(f"  Successfully updated subject names.")
        else:
            print(f"Updating Card {cid}...")
            fields_to_fix = list(set([f['field'] for f in fixes]))
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
                
                for fix in [f for f in fixes if f['field'] == f_base]:
                    local_map[fix['locale']] = fix['translated_text']
                
                escaped_val = json.dumps(local_map, ensure_ascii=False).replace("'", "''")
                update_sets.append(f"{f_json} = '{escaped_val}'")
            
            update_sql = f"UPDATE cards SET {', '.join(update_sets)}, updated_at = CURRENT_TIMESTAMP WHERE id = '{cid}'"
            if run_wrangler_update(update_sql):
                print(f"  Successfully updated card {cid}.")

    print("\nAll fixes applied successfully.")

if __name__ == "__main__":
    main()
