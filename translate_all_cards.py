import os
import json
from deep_translator import GoogleTranslator
import time

TARGET_LANGS = ['ar', 'ur', 'bn', 'pa', 'hi', 'mr', 'te', 'ta', 'th', 'fa', 'el', 'zh', 'ja', 'ko', 'id', 'de', 'es', 'fr', 'it', 'sw', 'nl', 'pl', 'pt', 'tl', 'vi', 'tr', 'uk']

def get_translator_code(code):
    if code == 'zh': return 'zh-CN'
    return code

def main():
    root_dir = os.path.expanduser("~/.aliolo/cards")
    json_files = []
    for root, dirs, files in os.walk(root_dir):
        for f in files:
            if f.endswith('.json') and f != 'meta.json':
                json_files.append(os.path.join(root, f))
    
    unique_prompts = set()
    unique_answers = set()
    
    # 1. Collect
    for f in json_files:
        with open(f, 'r', encoding='utf-8') as fp:
            data = json.load(fp)
            
            for p in data.get('prompts', []):
                if p.startswith('EN: '):
                    unique_prompts.add(p[4:].strip())
                elif not ":" in p: # Legacy without prefix
                    unique_prompts.add(p.strip())
                    
            for a in data.get('answers', []):
                if a.startswith('EN: '):
                    unique_answers.add(a[4:].strip())
                elif not ":" in a: # Legacy without prefix
                    unique_answers.add(a.strip())
                    
    all_texts = list(unique_prompts.union(unique_answers))
    print(f"Total unique texts to translate: {len(all_texts)}")
    
    # 2. Translate
    translations = {lang: {} for lang in TARGET_LANGS}
    
    chunk_size = 50
    for lang in TARGET_LANGS:
        print(f"Translating to {lang}...")
        t_code = get_translator_code(lang)
        translator = GoogleTranslator(source='en', target=t_code)
        
        for i in range(0, len(all_texts), chunk_size):
            chunk = all_texts[i:i+chunk_size]
            try:
                res = translator.translate_batch(chunk)
                for j, text in enumerate(chunk):
                    translations[lang][text] = res[j]
            except Exception as e:
                print(f"Error translating chunk for {lang}: {e}")
                time.sleep(2)
                try:
                    res = translator.translate_batch(chunk)
                    for j, text in enumerate(chunk):
                        translations[lang][text] = res[j]
                except Exception as e:
                    print(f"Failed again: {e}")
            time.sleep(0.5)

    print("Updating card files...")
    # 3. Update files
    for f in json_files:
        with open(f, 'r', encoding='utf-8') as fp:
            data = json.load(fp)
            
        en_prompts = []
        for p in data.get('prompts', []):
             if p.startswith('EN: '): en_prompts.append(p[4:].strip())
             elif not ":" in p: en_prompts.append(p.strip())
             
        en_answers = []
        for a in data.get('answers', []):
             if a.startswith('EN: '): en_answers.append(a[4:].strip())
             elif not ":" in a: en_answers.append(a.strip())
        
        if not en_prompts and not en_answers:
            continue
            
        new_prompts = []
        # To avoid duplicates, keep track
        seen_p = set()
        for ep in en_prompts:
            if ep in seen_p: continue
            seen_p.add(ep)
            new_prompts.append(f"EN: {ep}")
            for lang in TARGET_LANGS:
                if ep in translations[lang] and translations[lang][ep]:
                    new_prompts.append(f"{lang.upper()}: {translations[lang][ep]}")
                    
        new_answers = []
        seen_a = set()
        for ea in en_answers:
            if ea in seen_a: continue
            seen_a.add(ea)
            new_answers.append(f"EN: {ea}")
            for lang in TARGET_LANGS:
                if ea in translations[lang] and translations[lang][ea]:
                    new_answers.append(f"{lang.upper()}: {translations[lang][ea]}")
                    
        data['prompts'] = new_prompts
        data['answers'] = new_answers
        
        with open(f, 'w', encoding='utf-8') as fp:
            json.dump(data, fp, ensure_ascii=False, indent=2)

if __name__ == '__main__':
    main()
