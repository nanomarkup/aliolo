import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_IDS = [
    'e104da1c-9820-4e61-ae6b-bc7ed07eeb93', 'e204da1c-9820-4e61-ae6b-bc7ed07eeb93', 'e304da1c-9820-4e61-ae6b-bc7ed07eeb93',
    'e404da1c-9820-4e61-ae6b-bc7ed07eeb93', 'e504da1c-9820-4e61-ae6b-bc7ed07eeb93', 'e604da1c-9820-4e61-ae6b-bc7ed07eeb93',
    'e704da1c-9820-4e61-ae6b-bc7ed07eeb93', 'e804da1c-9820-4e61-ae6b-bc7ed07eeb93', 'e904da1c-9820-4e61-ae6b-bc7ed07eeb93',
    'd104da1c-9820-4e61-ae6b-bc7ed07eeb93', 'd204da1c-9820-4e61-ae6b-bc7ed07eeb93', 'd304da1c-9820-4e61-ae6b-bc7ed07eeb93',
    'd404da1c-9820-4e61-ae6b-bc7ed07eeb93', 'd504da1c-9820-4e61-ae6b-bc7ed07eeb93', 'd604da1c-9820-4e61-ae6b-bc7ed07eeb93',
    'd704da1c-9820-4e61-ae6b-bc7ed07eeb93', 'd804da1c-9820-4e61-ae6b-bc7ed07eeb93', 'd904da1c-9820-4e61-ae6b-bc7ed07eeb93'
]
COLLECTION_IDS = [
    'b104da1c-9820-4e61-ae6b-bc7ed07eeb93',
    'a104da1c-9820-4e61-ae6b-bc7ed07eeb93',
    'f304da1c-9820-4e61-ae6b-bc7ed07eeb93'
]
OUTPUT_SQL = Path("scripts/.tmp/multiply_divide_folder_fixes.sql")

def run_wrangler(sql):
    cmd = ["npx", "wrangler", "d1", "execute", DB_NAME, "--command", sql, "--remote", "--json"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    if res.returncode != 0:
        return []
    try:
        return json.loads(res.stdout)[0]["results"]
    except:
        return []

def get_localized_num(num_str, locale):
    try:
        val = int(num_str)
    except:
        return num_str

    if locale == 'ar':
        western = "0123456789"
        arabic = "٠١٢٣٤٥٦٧٨٩"
        return num_str.translate(str.maketrans(western, arabic))
    
    if locale == 'hi':
        western = "0123456789"
        hindi = "०१२३४५६७८९"
        return num_str.translate(str.maketrans(western, hindi))

    if locale in ['ja', 'zh']:
        # Hanzi/Kanji up to 99
        chars = ["〇", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        if val == 0: return chars[0]
        res = ""
        tens = val // 10
        ones = val % 10
        if tens > 1: res += chars[tens]
        if tens >= 1: res += "十"
        if ones > 0: res += chars[ones]
        return res

    if locale == 'ko':
        # Sino-Korean up to 99
        chars = ["영", "일", "이", "삼", "사", "오", "육", "칠", "팔", "구"]
        if val == 0: return chars[0]
        res = ""
        tens = val // 10
        ones = val % 10
        if tens > 1: res += chars[tens]
        if tens >= 1: res += "십"
        if ones > 0: res += chars[ones]
        return res

    return num_str

def localize_text(text, locale):
    if not text: return text
    # Extract digits and replace them specifically
    import re
    def replacer(match):
        return get_localized_num(match.group(0), locale)
    return re.sub(r'\d+', replacer, text)

def main():
    print("Fetching and fixing Multiply & Divide content...")
    s_ids = "', '".join(SUBJECT_IDS)
    c_ids = "', '".join(COLLECTION_IDS)
    
    subjects = run_wrangler(f"SELECT id, names, descriptions FROM subjects WHERE id IN ('{s_ids}')")
    collections = run_wrangler(f"SELECT id, names, descriptions FROM collections WHERE id IN ('{c_ids}')")
    
    sql_statements = []
    locales_with_native_nums = ['ar', 'hi', 'ja', 'zh', 'ko']

    # 1. Metadata
    for item_list, table in [(subjects, 'subjects'), (collections, 'collections')]:
        for item in item_list:
            names = json.loads(item['names'] or '{}')
            descs = json.loads(item['descriptions'] or '{}')
            for loc in locales_with_native_nums:
                if loc in names: names[loc] = localize_text(names[loc], loc)
                if loc in descs: descs[loc] = localize_text(descs[loc], loc)
            
            n_json = json.dumps(names, ensure_ascii=False).replace("'", "''")
            d_json = json.dumps(descs, ensure_ascii=False).replace("'", "''")
            sql_statements.append(f"UPDATE {table} SET names = '{n_json}', descriptions = '{d_json}', updated_at = CURRENT_TIMESTAMP WHERE id = '{item['id']}';")

    # 2. Cards
    for sid in SUBJECT_IDS:
        print(f"Processing cards for subject {sid}...")
        cards = run_wrangler(f"SELECT id, answer, answers, prompt, prompts, display_text, display_texts FROM cards WHERE subject_id = '{sid}'")
        for card in cards:
            ans = json.loads(card['answers'] or '{}')
            prm = json.loads(card['prompts'] or '{}')
            dsp = json.loads(card['display_texts'] or '{}')
            
            for loc in locales_with_native_nums:
                ans[loc] = get_localized_num(card['answer'], loc)
                dsp[loc] = get_localized_num(card['display_text'] or card['answer'], loc)
                if loc in prm: prm[loc] = localize_text(prm[loc], loc)
            
            # Gaelic
            base_p = card['prompt']
            if "Multiply" in base_p: prm['ga'] = "Iolraigh na rudaí:"
            elif "Divide" in base_p: prm['ga'] = "Roinn na rudaí:"
            ans['ga'] = card['answer']

            a_j = json.dumps(ans, ensure_ascii=False).replace("'", "''")
            p_j = json.dumps(prm, ensure_ascii=False).replace("'", "''")
            d_j = json.dumps(dsp, ensure_ascii=False).replace("'", "''")
            sql_statements.append(f"UPDATE cards SET answers = '{a_j}', prompts = '{p_j}', display_texts = '{d_j}', updated_at = CURRENT_TIMESTAMP WHERE id = '{card['id']}';")

    with open(OUTPUT_SQL, mode='w', encoding='utf-8') as f:
        f.write("-- Improved Comprehensive Localization Fixes for 'Multiply & Divide' folder\n")
        f.write("\n".join(sql_statements))
        f.write("\n")

    print(f"Generated {len(sql_statements)} SQL update statements.")
    print(f"SQL file: {OUTPUT_SQL}")

if __name__ == "__main__":
    main()
