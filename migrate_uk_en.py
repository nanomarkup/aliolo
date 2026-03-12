import os
import json

def migrate_uk_to_en():
    root = os.path.expanduser("~/.aliolo/cards")
    count = 0
    for path, dirs, files in os.walk(root):
        for f in files:
            if f.endswith(".json"):
                fp = os.path.join(path, f)
                try:
                    with open(fp, 'r') as file:
                        data = json.load(file)
                    
                    changed = False
                    # Update answers
                    if 'answers' in data:
                        new_answers = []
                        for ans in data['answers']:
                            if ans.startswith('UK: '):
                                new_answers.append(ans.replace('UK: ', 'EN: ', 1))
                                changed = True
                            else:
                                new_answers.append(ans)
                        data['answers'] = new_answers
                    
                    # Update prompts
                    if 'prompts' in data:
                        new_prompts = []
                        for pr in data['prompts']:
                            if pr.startswith('UK: '):
                                new_prompts.append(pr.replace('UK: ', 'EN: ', 1))
                                changed = True
                            else:
                                new_prompts.append(pr)
                        data['prompts'] = new_prompts
                    
                    if changed:
                        with open(fp, 'w') as file:
                            json.dump(data, file, indent=2)
                        count += 1
                except Exception as e:
                    print(f"Error migrating {fp}: {e}")
    print(f"Migrated {count} cards from UK to EN.")

if __name__ == "__main__":
    migrate_uk_to_en()
