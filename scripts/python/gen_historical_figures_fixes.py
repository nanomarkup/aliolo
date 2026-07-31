import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_ID = "02299d94-6d07-419f-b7df-ffcc048d412a"
OUTPUT_SQL = Path("scripts/.tmp/historical_figures_fixes.sql")

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
    print("Fetching Historical Figures data...")
    cards = run_wrangler(f"SELECT id, answer, answers, prompts, display_texts FROM cards WHERE subject_id = '{SUBJECT_ID}'")
    
    sql_statements = []

    ga_name_fixes = {
        "Napoleon Bonaparte": "Napoileon Bonapart",
        "William Shakespeare": "Uilliam Shakespeare",
        "Charles Darwin": "Séarlas Darwin",
        "William the Conqueror": "Uilliam an Concar",
        "Michelangelo": "Micheál Aingeal",
        "Philip II": "Pilib II",
        "Thomas Aquinas": "Tomás Acuineas",
        "John Calvin": "Eoin Cálvin",
        "John Locke": "Eoin Locke",
        "Vladimir Lenin": "Vlaidimír Leinín",
        "Andrew Jackson": "Aindréas Jackson",
        "Alexander the Great": "Alastar Mór",
        "Christopher Columbus": "Críostóir Colambas",
        "Marco Polo": "Marcas Polo",
        "James Cook": "Séamas Cook",
        "Charles V": "Séarlas V",
        "Richard Wagner": "Risteard Wagner",
        "Dante Alighieri": "Dante Alighieri",
        "Otto von Bismarck": "Otto von Bismarck"
    }

    for card in cards:
        cid = card['id']
        ans = json.loads(card['answers'] or '{}')
        prm = json.loads(card['prompts'] or '{}')
        dsp = json.loads(card['display_texts'] or '{}')
        global_ans = card['answer']
        
        # 1. Fix Gaelic answers
        if global_ans in ga_name_fixes:
            ans['ga'] = ga_name_fixes[global_ans]
        elif ans.get('ga') == global_ans:
            # Check for common patterns
            if "Charles" in global_ans: ans['ga'] = global_ans.replace("Charles", "Séarlas")
            if "William" in global_ans: ans['ga'] = global_ans.replace("William", "Uilliam")
            if "John" in global_ans: ans['ga'] = global_ans.replace("John", "Seán")
            if "James" in global_ans: ans['ga'] = global_ans.replace("James", "Séamas")

        # 2. Fix display_texts for target languages to match localized answer
        target_locales = ['ar', 'hi', 'ja', 'zh', 'ko']
        has_changes = False
        
        for loc in target_locales:
            if loc in ans and (not dsp.get(loc) or dsp.get(loc) != ans[loc]):
                dsp[loc] = ans[loc]
                has_changes = True

        # Always update if Gaelic was fixed too
        if global_ans in ga_name_fixes or has_changes:
            a_j = json.dumps(ans, ensure_ascii=False).replace("'", "''")
            p_j = json.dumps(prm, ensure_ascii=False).replace("'", "''")
            d_j = json.dumps(dsp, ensure_ascii=False).replace("'", "''")
            
            sql = f"UPDATE cards SET answers = '{a_j}', prompts = '{p_j}', display_texts = '{d_j}', updated_at = CURRENT_TIMESTAMP WHERE id = '{cid}';"
            sql_statements.append(sql)

    if not sql_statements:
        print("No fixes needed for cards.")
    else:
        with open(OUTPUT_SQL, mode='w', encoding='utf-8') as f:
            f.write("-- Localization Fixes for 'Historical Figures' subject\n")
            f.write("\n".join(sql_statements))
            f.write("\n")
        print(f"Generated {len(sql_statements)} SQL update statements.")
        print(f"SQL file: {OUTPUT_SQL}")

if __name__ == "__main__":
    main()
