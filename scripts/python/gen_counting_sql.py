import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
FIXES_CSV = Path("scripts/.tmp/counting_fixes.csv")
OUTPUT_SQL = Path("scripts/.tmp/counting_fixes.sql")

def run_wrangler(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return []
    try:
        return json.loads(res.stdout)[0]["results"]
    except:
        return []

def main():
    if not FIXES_CSV.exists():
        print("Fixes CSV not found.")
        return

    fixes_by_card = {}
    with open(FIXES_CSV, mode='r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            cid = row['card_id']
            if cid not in fixes_by_card: fixes_by_card[cid] = []
            fixes_by_card[cid].append(row)

    sql_statements = []
    
    for cid, fixes in fixes_by_card.items():
        print(f"Processing card {cid}...")
        res = run_wrangler(f"SELECT answers, prompts, display_texts FROM cards WHERE id = '{cid}'")
        if not res: continue
        
        card_data = res[0]
        answers = json.loads(card_data['answers'] or '{}')
        prompts = json.loads(card_data['prompts'] or '{}')
        display_texts = json.loads(card_data['display_texts'] or '{}')
        
        for fix in fixes:
            field = fix['field']
            locale = fix['locale']
            new_val = fix['new_value']
            
            if field == 'answer':
                answers[locale] = new_val
            elif field == 'prompt':
                prompts[locale] = new_val

        ans_json = json.dumps(answers, ensure_ascii=False).replace("'", "''")
        prm_json = json.dumps(prompts, ensure_ascii=False).replace("'", "''")
        dsp_json = json.dumps(display_texts, ensure_ascii=False).replace("'", "''")
        
        sql = f"UPDATE cards SET answers = '{ans_json}', prompts = '{prm_json}', display_texts = '{dsp_json}', updated_at = CURRENT_TIMESTAMP WHERE id = '{cid}';"
        sql_statements.append(sql)

    with open(OUTPUT_SQL, mode='w', encoding='utf-8') as f:
        f.write("-- Production fixes for Counting\n")
        f.write("\n".join(sql_statements))
        f.write("\n")

    print(f"Generated {len(sql_statements)} SQL update statements.")
    print(f"SQL file: {OUTPUT_SQL}")

if __name__ == "__main__":
    main()
