import os
import json
from deep_translator import GoogleTranslator
import time

TARGET_LANGS = ['ar', 'ur', 'bn', 'pa', 'hi', 'mr', 'te', 'ta', 'th', 'fa', 'el', 'zh', 'ja', 'ko', 'id', 'de', 'es', 'fr', 'it', 'sw', 'nl', 'pl', 'pt', 'tl', 'vi', 'tr', 'uk']

def get_translator_code(code):
    if code == 'zh': return 'zh-CN'
    return code

def translate_subject(subject_name):
    root_dir = os.path.expanduser(f"~/.aliolo/cards/{subject_name}")
    if not os.path.exists(root_dir):
        print(f"Subject directory {subject_name} not found.")
        return

    json_files = [os.path.join(root_dir, f) for f in os.listdir(root_dir) if f.endswith('.json') and f != 'meta.json']
    unique_answers = set()
    
    # 1. Collect
    for f in json_files:
        with open(f, 'r', encoding='utf-8') as fp:
            data = json.load(fp)
            # Find the English source
            en_val = ""
            for a in data.get('answers', []):
                if a.startswith('EN: '): 
                    en_val = a[4:].strip()
                    break
                elif not ":" in a: 
                    en_val = a.strip()
                    break
            
            if en_val:
                # Check which languages are missing
                existing_langs = [ans.split(':')[0].lower() for ans in data.get('answers', [])]
                for target in TARGET_LANGS:
                    if target not in existing_langs:
                        unique_answers.add((en_val, target))
                    
    tasks = list(unique_answers)
    print(f"[{subject_name}] Pending translation tasks: {len(tasks)}")
    if not tasks: return

    # Group tasks by language
    tasks_by_lang = {}
    for text, lang in tasks:
        tasks_by_lang.setdefault(lang, set()).add(text)

    # 2. Translate and Update incrementally
    for lang, texts in tasks_by_lang.items():
        print(f"  Translating to {lang}...")
        t_code = get_translator_code(lang)
        translator = GoogleTranslator(source='en', target=t_code)
        
        text_list = list(texts)
        lang_map = {}
        chunk_size = 25
        for i in range(0, len(text_list), chunk_size):
            chunk = text_list[i:i+chunk_size]
            try:
                res = translator.translate_batch(chunk)
                for j, original in enumerate(chunk):
                    lang_map[original] = res[j]
                time.sleep(1)
            except Exception as e:
                print(f"    Error translating {lang}: {e}")
                time.sleep(2)

        # Apply to files immediately for this language
        for f in json_files:
            with open(f, 'r', encoding='utf-8') as fp:
                data = json.load(fp)
            
            en_a = ""
            for a in data.get('answers', []):
                if a.startswith('EN: '): 
                    en_a = a[4:].strip()
                    break
            
            if en_a in lang_map:
                if not any(a.startswith(f"{lang.upper()}:") for a in data['answers']):
                    data['answers'].append(f"{lang.upper()}: {lang_map[en_a]}")
                    with open(f, 'w', encoding='utf-8') as fp:
                        json.dump(data, fp, ensure_ascii=False, indent=2)

def main():
    root_cards_dir = os.path.expanduser("~/.aliolo/cards/")
    if not os.path.exists(root_cards_dir):
        print(f"Cards directory {root_cards_dir} not found.")
        return
    
    subjects = [s for s in os.listdir(root_cards_dir) if os.path.isdir(os.path.join(root_cards_dir, s))]
    for s in subjects:
        translate_subject(s)

if __name__ == '__main__':
    main()
