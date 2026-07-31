import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_IDS = [
    'de04da1c-9820-4e61-ae6b-bc7ed07eeb93', # Addition 0-10
    '5e81da1f-f92c-44d2-b3cd-f921d05425df', # Addition 11-20
    'ce04da1c-9820-4e61-ae6b-bc7ed07eeb93', # Subtraction 0-10
    'f59a0f9c-5d6d-4f2d-b426-eb9ca6bf2782'  # Subtraction 11-20
]
COLLECTION_IDS = [
    'e104da1c-9820-4e61-ae6b-bc7ed07eeb93', # Subtraction 20
    'd104da1c-9820-4e61-ae6b-bc7ed07eeb93', # Addition 20
    'f204da1c-9820-4e61-ae6b-bc7ed07eeb93'  # Add & Subtract 20
]
OUTPUT_SQL = Path("scripts/.tmp/add_subtract_folder_fixes.sql")

def run_wrangler(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return []
    try:
        return json.loads(res.stdout)[0]["results"]
    except:
        return []

def get_localized_num(num_str, locale, is_metadata=False):
    # Mapping for numbers 0-20
    # For metadata (0, 10, 20), we use the same as answers but sometimes Kanji for 10/20 is preferred.
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

def localize_text(text, locale):
    if not text: return text
    # Replace numbers 0-20 in text strings (metadata descriptions)
    # Sort by length descending to avoid partial replacements (e.g., 10 before 1)
    for i in range(20, -1, -1):
        l_num = get_localized_num(str(i), locale, True)
        text = text.replace(str(i), l_num)
    return text

def main():
    print("Fetching and fixing all Add & Subtract content...")
    s_ids = "', '".join(SUBJECT_IDS)
    c_ids = "', '".join(COLLECTION_IDS)
    
    subjects = run_wrangler(f"SELECT id, names, descriptions FROM subjects WHERE id IN ('{s_ids}')")
    collections = run_wrangler(f"SELECT id, names, descriptions FROM collections WHERE id IN ('{c_ids}')")
    cards = run_wrangler(f"SELECT id, answer, answers, prompt, prompts, display_texts FROM cards WHERE subject_id IN ('{s_ids}')")
    
    sql_statements = []
    locales_with_native_nums = ['ar', 'hi', 'ja', 'zh', 'ko']

    # 1. Subject Metadata
    for s in subjects:
        names = json.loads(s['names'] or '{}')
        descs = json.loads(s['descriptions'] or '{}')
        for loc in locales_with_native_nums:
            if loc in names: names[loc] = localize_text(names[loc], loc)
            if loc in descs: descs[loc] = localize_text(descs[loc], loc)
        
        n_json = json.dumps(names, ensure_ascii=False).replace("'", "''")
        d_json = json.dumps(descs, ensure_ascii=False).replace("'", "''")
        sql_statements.append(f"UPDATE subjects SET names = '{n_json}', descriptions = '{d_json}', updated_at = CURRENT_TIMESTAMP WHERE id = '{s['id']}';")

    # 2. Collection Metadata
    for c in collections:
        names = json.loads(c['names'] or '{}')
        descs = json.loads(c['descriptions'] or '{}')
        for loc in locales_with_native_nums:
            if loc in names: names[loc] = localize_text(names[loc], loc)
            if loc in descs: descs[loc] = localize_text(descs[loc], loc)
        
        n_json = json.dumps(names, ensure_ascii=False).replace("'", "''")
        d_json = json.dumps(descs, ensure_ascii=False).replace("'", "''")
        sql_statements.append(f"UPDATE collections SET names = '{n_json}', descriptions = '{d_json}', updated_at = CURRENT_TIMESTAMP WHERE id = '{c['id']}';")

    # 3. Cards
    for card in cards:
        ans = json.loads(card['answers'] or '{}')
        prm = json.loads(card['prompts'] or '{}')
        dsp = json.loads(card['display_texts'] or '{}')
        
        # Localize Digits
        for loc in locales_with_native_nums:
            # Answer
            ans[loc] = get_localized_num(card['answer'], loc)
            # Display Text
            dsp[loc] = get_localized_num(card['answer'], loc)
            # Prompt (if it has digits, though usually they don't in Add/Subtract)
            if loc in prm:
                prm[loc] = localize_text(prm[loc], loc)

        # Gaelic fixes
        ga_prompt = prm.get('ga')
        # Check original English prompt to decide which Gaelic to use
        # I'll need to fetch the global prompt too, let me re-query or assume based on subject
        # I'll fetch them in the loop
        
        # Re-fetching for prompt logic consistency
        full_card = run_wrangler(f"SELECT prompt FROM cards WHERE id = '{card['id']}'")[0]
        base_prompt = full_card['prompt']
        
        new_ga_prompt = None
        if base_prompt == "Add the objects:":
            new_ga_prompt = "Cuir na rudaí leis:"
        elif base_prompt == "Subtract the objects:":
            new_ga_prompt = "Bain na rudaí:"
            
        if new_ga_prompt:
            prm['ga'] = new_ga_prompt
        
        # Gaelic numeric answer
        ans['ga'] = card['answer']

        a_json = json.dumps(ans, ensure_ascii=False).replace("'", "''")
        p_json = json.dumps(prm, ensure_ascii=False).replace("'", "''")
        d_json = json.dumps(dsp, ensure_ascii=False).replace("'", "''")
        sql_statements.append(f"UPDATE cards SET answers = '{a_json}', prompts = '{p_json}', display_texts = '{d_json}', updated_at = CURRENT_TIMESTAMP WHERE id = '{card['id']}';")

    with open(OUTPUT_SQL, mode='w', encoding='utf-8') as f:
        f.write("-- Comprehensive Localization Fixes for 'Add & Subtract' folder\n")
        f.write("\n".join(sql_statements))
        f.write("\n")

    print(f"Generated {len(sql_statements)} SQL update statements.")
    print(f"SQL file: {OUTPUT_SQL}")

if __name__ == "__main__":
    main()
