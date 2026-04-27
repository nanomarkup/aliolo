import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_IDS = ['de04da1c-9820-4e61-ae6b-bc7ed07eeb93', 'ce04da1c-9820-4e61-ae6b-bc7ed07eeb93']
OUTPUT_CSV = Path("scripts/.tmp/math_fixes.csv")

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
    print("Fetching cards from DB...")
    ids_str = "', '".join(SUBJECT_IDS)
    cards = run_wrangler(f"SELECT id, subject_id, answer, answers, prompt, prompts FROM cards WHERE subject_id IN ('{ids_str}')")
    
    if not cards:
        print("No cards found.")
        return

    fixes = []
    
    for card in cards:
        cid = card['id']
        answers = json.loads(card['answers'] or '{}')
        prompts = json.loads(card['prompts'] or '{}')
        
        # Determine intended prompt based on English
        base_prompt = card['prompt']
        ga_prompt = prompts.get('ga')
        
        new_ga_prompt = None
        if base_prompt == "Add the objects:":
            new_ga_prompt = "Cuir na rudaí leis:"
        elif base_prompt == "Subtract the objects:":
            new_ga_prompt = "Bain na rudaí:"
            
        if new_ga_prompt and ga_prompt != new_ga_prompt:
             fixes.append({
                'card_id': cid,
                'field': 'prompt',
                'locale': 'ga',
                'old_value': ga_prompt,
                'new_value': new_ga_prompt
            })
            
        # Gaelic answer (numbers are usually the same, but let's ensure 'ga' key exists for consistency if others have it)
        ga_answer = answers.get('ga')
        if ga_answer != card['answer']:
            fixes.append({
                'card_id': cid,
                'field': 'answer',
                'locale': 'ga',
                'old_value': ga_answer,
                'new_value': card['answer']
            })

    if not fixes:
        print("No fixes found.")
        return

    with open(OUTPUT_CSV, mode='w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=['card_id', 'field', 'locale', 'old_value', 'new_value'])
        writer.writeheader()
        writer.writerows(fixes)
    
    print(f"Generated {len(fixes)} fixes.")
    print(f"CSV saved to: {OUTPUT_CSV}")

if __name__ == "__main__":
    main()
