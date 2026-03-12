import os
import json
from deep_translator import GoogleTranslator
import time

TARGET_LANGS = ['ar', 'ur', 'bn', 'pa', 'hi', 'mr', 'te', 'ta', 'th', 'fa', 'el', 'zh', 'ja', 'ko', 'id', 'de', 'es', 'fr', 'it', 'sw', 'nl', 'pl', 'pt', 'tl', 'vi', 'tr', 'uk']

def get_translator_code(code):
    if code == 'zh': return 'zh-CN'
    return code

def main():
    root_dir = os.path.expanduser("~/.aliolo/cards/Astronomy")
    json_files = [os.path.join(root_dir, f) for f in os.listdir(root_dir) if f.endswith('.json') and f != 'meta.json']
    
    unique_answers = set()
    
    # 1. Collect unique English terms
    for f in json_files:
        with open(f, 'r', encoding='utf-8') as fp:
            data = json.load(fp)
            for a in data.get('answers', []):
                if a.startswith('EN: '):
                    unique_answers.add(a[4:].strip())
                elif not ":" in a:
                    unique_answers.add(a.strip())
                    
    all_texts = list(unique_answers)
    print(f"Total unique astronomy terms to translate: {len(all_texts)}")
    
    # 2. Translate by language
    translations_by_lang = {}
    for lang in TARGET_LANGS:
        print(f"Translating to {lang}...")
        t_code = get_translator_code(lang)
        translator = GoogleTranslator(source='en', target=t_code)
        
        lang_map = {}
        chunk_size = 25
        for i in range(0, len(all_texts), chunk_size):
            chunk = all_texts[i:i+chunk_size]
            try:
                res = translator.translate_batch(chunk)
                for j, text in enumerate(chunk):
                    lang_map[text] = res[j]
                time.sleep(1)
            except Exception as e:
                print(f"  Error translating chunk: {e}")
                time.sleep(2)
        translations_by_lang[lang] = lang_map

    # 3. Update files
    print("Updating astronomy files...")
    for f in json_files:
        with open(f, 'r', encoding='utf-8') as fp:
            data = json.load(fp)
            
        en_val = ""
        for a in data.get('answers', []):
            if a.startswith('EN: '): en_val = a[4:].strip()
            elif not ":" in a: en_val = a.strip()
        
        if not en_val: continue
            
        new_answers = [f"EN: {en_val}"]
        for lang in TARGET_LANGS:
            val = translations_by_lang[lang].get(en_val)
            if val:
                new_answers.append(f"{lang.upper()}: {val}")
        
        data['answers'] = new_answers
        with open(f, 'w', encoding='utf-8') as fp:
            json.dump(data, fp, ensure_ascii=False, indent=2)

if __name__ == '__main__':
    main()
