import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_ID = "4b210d48-c309-4c4b-ad80-24b9f8dde33e"
OUTPUT_SQL = Path("scripts/.tmp/food_cuisines_fixes.sql")

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
    print("Fetching Food & Cuisines data...")
    cards = run_wrangler(f"SELECT id, answer, answers, prompts, display_texts FROM cards WHERE subject_id = '{SUBJECT_ID}'")
    
    sql_statements = []

    for card in cards:
        cid = card['id']
        ans = json.loads(card['answers'] or '{}')
        prm = json.loads(card['prompts'] or '{}')
        dsp = json.loads(card['display_texts'] or '{}')
        
        # User constraint: Do not add prompt if it is missing in global data.
        # Global prompt is fetched as empty in previous step.
        
        # Fix display_texts for target languages to match localized answer
        target_locales = ['ar', 'hi', 'ja', 'zh', 'ko']
        has_changes = False
        
        for loc in target_locales:
            if loc in ans and (not dsp.get(loc) or dsp.get(loc) != ans[loc]):
                dsp[loc] = ans[loc]
                has_changes = True

        if has_changes:
            # We only update if we found missing display_texts. 
            # We preserve existing prompts (which are {})
            a_j = json.dumps(ans, ensure_ascii=False).replace("'", "''")
            p_j = json.dumps(prm, ensure_ascii=False).replace("'", "''")
            d_j = json.dumps(dsp, ensure_ascii=False).replace("'", "''")
            
            sql = f"UPDATE cards SET answers = '{a_j}', prompts = '{p_j}', display_texts = '{d_j}', updated_at = CURRENT_TIMESTAMP WHERE id = '{cid}';"
            sql_statements.append(sql)

    if not sql_statements:
        print("No fixes needed for cards.")
    else:
        with open(OUTPUT_SQL, mode='w', encoding='utf-8') as f:
            f.write("-- Localization Fixes for 'Food & Cuisines' subject\n")
            f.write("\n".join(sql_statements))
            f.write("\n")
        print(f"Generated {len(sql_statements)} SQL update statements.")
        print(f"SQL file: {OUTPUT_SQL}")

if __name__ == "__main__":
    main()
