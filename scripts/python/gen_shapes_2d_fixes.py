import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_ID = "031f918e-6afa-469b-97bc-48a65e565237"
OUTPUT_CSV = Path("scripts/.tmp/shapes_2d_fixes.csv")

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
    cards = run_wrangler(f"SELECT id, answer, answers, prompt, prompts FROM cards WHERE subject_id = '{SUBJECT_ID}'")
    
    if not cards:
        print("No cards found.")
        return

    ga_answer_map = {
        "Parallelogram": "Comhthreomharán",
        "Semi-circle": "Leathchiorcal",
        "Oval": "Oval",
        "Diamond": "Rombas",
        "Circle": "Ciorcal",
        "Octagon": "Ochtaagán",
        "Pentagon": "Peinteagán",
        "Square": "Cearnóg",
        "Heart": "Croí",
        "Cross": "Cros",
        "Triangle": "Triantán",
        "Trapezoid": "Traipeasóid",
        "Rectangle": "Dronuilleog"
    }

    fixes = []
    
    for card in cards:
        cid = card['id']
        answers = json.loads(card['answers'] or '{}')
        prompts = json.loads(card['prompts'] or '{}')
        
        # Check Gaelic prompt
        ga_prompt = prompts.get('ga')
        if ga_prompt == "Select the correct shape:" or not ga_prompt:
            fixes.append({
                'card_id': cid,
                'field': 'prompt',
                'locale': 'ga',
                'old_value': ga_prompt,
                'new_value': "Cén cruth atá air seo?"
            })
            
        # Check Gaelic answer
        global_answer = card['answer']
        ga_answer = answers.get('ga')
        expected_ga = ga_answer_map.get(global_answer)
        
        if expected_ga and ga_answer != expected_ga:
            fixes.append({
                'card_id': cid,
                'field': 'answer',
                'locale': 'ga',
                'old_value': ga_answer,
                'new_value': expected_ga
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
