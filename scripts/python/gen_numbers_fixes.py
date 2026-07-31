import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_ID = "bc354f43-f9be-42a9-a7bc-ac400bd5e310"
OUTPUT_CSV = Path("scripts/.tmp/numbers_fixes.csv")

def run_wrangler(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return []
    try:
        return json.loads(res.stdout)[0]["results"]
    except:
        return []

def get_localized_number(num_str, locale):
    # Mapping for numbers 0-20
    maps = {
        'ar': ["٠", "١", "٢", "٣", "٤", "٥", "٦", "٧", "٨", "٩", "١٠", "١١", "١٢", "١٣", "١٤", "١٥", "١٦", "١٧", "١٨", "١٩", "٢٠"],
        'hi': ["०", "१", "२", "३", "४", "५", "६", "७", "८", "९", "१०", "११", "१२", "१३", "१४", "१५", "१६", "१७", "१८", "१९", "२०"],
        'ja': ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十"],
        'zh': ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十", "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十"],
        'ko': ["영", "일", "이", "삼", "사", "오", "육", "칠", "팔", "구", "십", "십일", "십이", "십삼", "십사", "십오", "십육", "십칠", "십팔", "십구", "이십"]
    }
    
    try:
        val = int(num_str)
        if locale in maps and 0 <= val <= 20:
            return maps[locale][val]
    except:
        pass
    return num_str

def main():
    print("Fetching cards from DB...")
    cards = run_wrangler(f"SELECT id, answer, answers, prompt, prompts, display_text, display_texts FROM cards WHERE subject_id = '{SUBJECT_ID}'")
    
    if not cards:
        print("No cards found.")
        return

    fixes = []
    locales_to_fix = ['ar', 'hi', 'ja', 'zh', 'ko']
    
    for card in cards:
        cid = card['id']
        answers = json.loads(card['answers'] or '{}')
        prompts = json.loads(card['prompts'] or '{}')
        display_texts = json.loads(card['display_texts'] or '{}')
        global_answer = card['answer']
        global_display = card['display_text']
        
        # 1. Fix Answers for specific locales
        for locale in locales_to_fix:
            expected_val = get_localized_number(global_answer, locale)
            
            # Check answer
            if answers.get(locale) != expected_val:
                fixes.append({
                    'card_id': cid,
                    'field': 'answer',
                    'locale': locale,
                    'old_value': answers.get(locale),
                    'new_value': expected_val
                })
            
            # Check display_text
            expected_display = get_localized_number(global_display, locale)
            if display_texts.get(locale) != expected_display:
                fixes.append({
                    'card_id': cid,
                    'field': 'display_text',
                    'locale': locale,
                    'old_value': display_texts.get(locale),
                    'new_value': expected_display
                })
        
        # 2. Fix Gaelic prompt
        ga_prompt = prompts.get('ga')
        if not ga_prompt or ga_prompt == "Select the correct shape:":
             fixes.append({
                'card_id': cid,
                'field': 'prompt',
                'locale': 'ga',
                'old_value': ga_prompt,
                'new_value': "Roghnaigh an uimhir cheart:"
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
