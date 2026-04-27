import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_ID = "7c85b685-6821-4906-a0e6-e5baaa49b5bc"
OUTPUT_SQL = Path("scripts/.tmp/musical_instruments_fixes.sql")

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
    print("Fetching Musical Instruments data...")
    subj = run_wrangler(f"SELECT names, descriptions FROM subjects WHERE id = '{SUBJECT_ID}'")[0]
    cards = run_wrangler(f"SELECT id, answer, answers, prompts, display_texts FROM cards WHERE subject_id = '{SUBJECT_ID}'")
    
    sql_statements = []

    # 1. Subject Metadata Improvements
    # Names and descriptions were mostly fine but we can standardize synonyms if needed.
    # User focused on cards, but let's ensure Gaelic prompt for instrument identification.
    
    # 2. Card Prompts (The main missing part)
    # We want "What instrument is this?" or similar localized.
    
    prompts_map = {
        "en": "What instrument is this?",
        "ar": "ما هذه الآلة؟",
        "bg": "Какъв е този инструмент?",
        "cs": "Jaký je to nástroj?",
        "da": "Hvilket instrument er dette?",
        "de": "Welches Instrument ist das?",
        "el": "Τι όργανο είναι αυτό;",
        "es": "¿Qué instrumento es este?",
        "et": "Mis pill see on?",
        "fi": "Mikä soitin tämä on?",
        "fr": "Quel est cet instrument ?",
        "ga": "Cén uirlis í seo?",
        "hi": "यह कौन सा वाद्य यंत्र है?",
        "hr": "Koji je ovo instrument?",
        "hu": "Milyen hangszer ez?",
        "id": "Alat musik apa ini?",
        "it": "Che strumento è questo?",
        "ja": "これは何の楽器ですか？",
        "ko": "이것은 어떤 악기입니까?",
        "lt": "Koks tai instrumentas?",
        "lv": "Kāds tas ir instruments?",
        "mt": "X'strument hu dan?",
        "nl": "Welk instrument is dit?",
        "pl": "Co to za instrument?",
        "pt": "Que instrumento é este?",
        "ro": "Ce instrument este acesta?",
        "sk": "Aký je to nástroj?",
        "sl": "Katero glasbilo je to?",
        "sv": "Vilket instrument är detta?",
        "tl": "Anong instrumento ito?",
        "tr": "Bu hangi enstrüman?",
        "uk": "Який це інструмент?",
        "vi": "Đây là nhạc cụ gì?",
        "zh": "这是什么乐器？"
    }

    for card in cards:
        cid = card['id']
        ans = json.loads(card['answers'] or '{}')
        prm = json.loads(card['prompts'] or '{}')
        dsp = json.loads(card['display_texts'] or '{}')
        
        # Standardize prompts for all languages
        prm.update(prompts_map)
        
        # Ensure display_texts for 5 target languages matches localized answer if not present
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
        f.write("-- Localization Fixes for 'Musical Instruments' subject\n")
        f.write("\n".join(sql_statements))
        f.write("\n")

    print(f"Generated {len(sql_statements)} SQL update statements.")
    print(f"SQL file: {OUTPUT_SQL}")

if __name__ == "__main__":
    main()
