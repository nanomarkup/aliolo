import os
import json

PROMPT_TRANSLATIONS = {
    "AR": "ما هذا؟",
    "UR": "یہ کیا ہے؟",
    "BN": "এটা কি?",
    "PA": "ਇਹ ਕੀ ਹੈ?",
    "HI": "यह क्या है?",
    "MR": "हे काय आहे?",
    "TE": "ఇది ఏమిటి?",
    "TA": "இது என்ன?",
    "TH": "นี่คืออะไร?",
    "FA": "این چیست؟",
    "EL": "Τι είναι αυτό;",
    "ZH": "这是什么？",
    "JA": "これは何ですか？",
    "KO": "이것은 무엇입니까？",
    "ID": "Apa ini?",
    "DE": "Was ist das?",
    "EN": "What is this?",
    "ES": "¿Qué es esto?",
    "FR": "Qu'est-ce que c'est ?",
    "IT": "Cos'è questo?",
    "SW": "Hii ni nini?",
    "NL": "Wat is dit?",
    "PL": "Co to jest?",
    "PT": "O que é isto?",
    "TL": "Ano ito?",
    "VI": "Đây là cái gì?",
    "TR": "Bu nedir?",
    "UK": "Що це?"
}

def update_prompts(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        try:
            data = json.load(f)
        except Exception:
            return

    # Create new prompts list based on our dictionary
    new_prompts = []
    for lang, text in PROMPT_TRANSLATIONS.items():
        new_prompts.append(f"{lang}: {text}")
    
    data["prompts"] = new_prompts
    
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def main():
    root = os.path.expanduser("~/.aliolo/cards")
    count = 0
    for path, dirs, files in os.walk(root):
        for file in files:
            if file.endswith(".json") and file != "meta.json":
                update_prompts(os.path.join(path, file))
                count += 1
    print(f"Successfully updated prompts in {count} cards.")

if __name__ == "__main__":
    main()
