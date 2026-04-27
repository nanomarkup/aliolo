import json
import subprocess
import sys

DB_NAME = "aliolo-db"

def run_wrangler_update(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    return res.returncode == 0

def update_card_answers(card_id, fixes):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", f"SELECT answers FROM cards WHERE id = '{card_id}'", "--remote", "--json"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    data = json.loads(res.stdout)
    answers = json.loads(data[0]['results'][0]['answers'] or '{}')
    
    for lang, val in fixes.items():
        answers[lang] = val
        
    escaped_json = json.dumps(answers, ensure_ascii=False).replace("'", "''")
    sql = f"UPDATE cards SET answers = '{escaped_json}', updated_at = CURRENT_TIMESTAMP WHERE id = '{card_id}'"
    run_wrangler_update(sql)

def main():
    print("Applying specific quality fixes for Colors subject...")

    # Fix 'Red' in Croatian
    update_card_answers('e1f5956c-e48c-4660-bd88-8b42cbf1c8e3', {'hr': 'Crvena'})
    print("  Updated 'Red' in Croatian.")

    # Fix 'Periwinkle' in multiple languages (removing snail references)
    periwinkle_fixes = {
        'lt': 'žiemė',
        'tr': 'cezayir menekşesi',
        'sv': 'vintergröna',
        'ko': '빙카'
    }
    update_card_answers('941482e0-d541-43cd-b8cd-2a41ff31cfca', periwinkle_fixes)
    print("  Updated 'Periwinkle' in Lithuanian, Turkish, Swedish, and Korean.")

    print("\nAll fixes applied successfully.")

if __name__ == "__main__":
    main()
