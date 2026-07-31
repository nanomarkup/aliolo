import json
import csv
import subprocess
from pathlib import Path

DB_NAME = "aliolo-db"
SUBJECT_ID = "a3f500b9-a631-4e63-bdfb-ce5e53156163"
OUTPUT_SQL = Path("scripts/.tmp/architectural_styles_fixes.sql")

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
    print("Fetching Architectural Styles data...")
    cards = run_wrangler(f"SELECT id, answer, answers, prompts, display_texts FROM cards WHERE subject_id = '{SUBJECT_ID}'")
    
    sql_statements = []

    prompts_map = {
        "en": "What architectural style is this?",
        "ar": "ما هو هذا النمط المعماري؟",
        "bg": "Какъв архитектурен стил е това?",
        "cs": "Jaký je to architektonický styl?",
        "da": "Hvilken arkitektonisk stil er dette?",
        "de": "Welcher Architekturstil ist das?",
        "el": "Ποιο αρχιτεκτονικό στυλ είναι αυτό;",
        "es": "¿Qué estilo arquitectónico es este?",
        "et": "Mis arhitektuuristiil see on?",
        "fi": "Mikä arkkitehtuurityyli tämä on?",
        "fr": "Quel est ce style architectural ?",
        "ga": "Cén stíl ailtireachta í seo?",
        "hi": "यह कौन सी स्थापत्य शैली है?",
        "hr": "Koji je ovo arhitektonski stil?",
        "hu": "Milyen építészeti stílus ez?",
        "id": "Gaya arsitektur apa ini?",
        "it": "Che stile architettonico è questo?",
        "ja": "これは何の建築様式ですか？",
        "ko": "이것은 어떤 건축 양식입니까?",
        "lt": "Koks tai architektūros stilius?",
        "lv": "Kāds tas ir arhitektūras stils?",
        "mt": "X'stil arkitettoniku hu dan?",
        "nl": "Welke architectuurstijl is dit?",
        "pl": "Co to za styl architektoniczny?",
        "pt": "Que estilo arquitetônico é este?",
        "ro": "Ce stil arhitectural este acesta?",
        "sk": "Aký je to architektonický štýl?",
        "sl": "Kateri arhitekturni slog je to?",
        "sv": "Vilken arkitektonisk stil är detta?",
        "tl": "Anong istilo ng arkitektura ito?",
        "tr": "Bu hangi mimari tarz?",
        "uk": "Який це архітектурний стиль?",
        "vi": "Đây là phong cách kiến ​​trúc gì?",
        "zh": "这是什么建筑风格？"
    }

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
        f.write("-- Localization Fixes for 'Architectural Styles' subject\n")
        f.write("\n".join(sql_statements))
        f.write("\n")

    print(f"Generated {len(sql_statements)} SQL update statements.")
    print(f"SQL file: {OUTPUT_SQL}")

if __name__ == "__main__":
    main()
