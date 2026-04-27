import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_ID = "2f0d2ba6-165f-4b1f-9460-0fb6eba79715"
OUTPUT_SQL = Path("scripts/.tmp/famous_paintings_fixes.sql")

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
    print("Fetching Famous Paintings data...")
    cards = run_wrangler(f"SELECT id, answer, answers, prompts, display_texts FROM cards WHERE subject_id = '{SUBJECT_ID}'")
    
    sql_statements = []

    prompts_map = {
        "en": "What painting is this?",
        "ar": "ما هي هذه اللوحة؟",
        "bg": "Каква е тази картина?",
        "cs": "Co je to за картина?",
        "da": "Hvilket maleri er dette?",
        "de": "Welches Gemälde ist das?",
        "el": "Τι πίνακας είναι αυτός;",
        "es": "¿Qué cuadro es este?",
        "et": "Mis maal see on?",
        "fi": "Mikä maalaus tämä on?",
        "fr": "Quel est ce tableau ?",
        "ga": "Cén phictiúr é seo?",
        "hi": "यह कौन सा चित्र है?",
        "hr": "Koja je ovo slika?",
        "hu": "Milyen festmény ez?",
        "id": "Lukisan apa ini?",
        "it": "Che dipinto è questo?",
        "ja": "これは何の絵ですか？",
        "ko": "이것은 어떤 그림입니까?",
        "lt": "Koks tai paveikslas?",
        "lv": "Kāda tā ir glezna?",
        "mt": "X'pittura hi din?",
        "nl": "Welk schilderij is dit?",
        "pl": "Co to za obraz?",
        "pt": "Que pintura é esta?",
        "ro": "Ce pictură este aceasta?",
        "sk": "Aký je to obraz?",
        "sl": "Katera slika je to?",
        "sv": "Vilken målning är detta?",
        "tl": "Anong painting ito?",
        "tr": "Bu hangi tablo?",
        "uk": "Яка це картина?",
        "vi": "Đây là bức tranh gì?",
        "zh": "这是什么画？"
    }

    # Custom prompt adjustment for Czech as suggested by typical translations
    prompts_map["cs"] = "Co je to za obraz?"

    for card in cards:
        cid = card['id']
        ans = json.loads(card['answers'] or '{}')
        prm = json.loads(card['prompts'] or '{}')
        dsp = json.loads(card['display_texts'] or '{}')
        
        # Standardize prompts
        prm.update(prompts_map)
        
        # Ensure display_texts for target languages
        target_locales = ['ar', 'hi', 'ja', 'zh', 'ko']
        for loc in target_locales:
            if loc in ans and (not dsp.get(loc)):
                dsp[loc] = ans[loc]

        a_j = json.dumps(ans, ensure_ascii=False).replace("'", "''")
        p_j = json.dumps(prm, ensure_ascii=False).replace("'", "''")
        d_j = json.dumps(dsp, ensure_ascii=False).replace("'", "''")
        
        sql = f"UPDATE cards SET answers = '{a_j}', prompts = '{p_j}', display_texts = '{d_j}', updated_at = CURRENT_TIMESTAMP WHERE id = '{cid}';"
        sql_statements.append(sql)

    with open(OUTPUT_SQL, mode='w', encoding='utf-8') as f:
        f.write("-- Localization Fixes for 'Famous Paintings' subject\n")
        f.write("\n".join(sql_statements))
        f.write("\n")

    print(f"Generated {len(sql_statements)} SQL update statements.")
    print(f"SQL file: {OUTPUT_SQL}")

if __name__ == "__main__":
    main()
