import os
import json

def update_cards():
    root = os.path.expanduser("~/.aliolo/cards")
    count = 0
    for path, dirs, files in os.walk(root):
        for f in files:
            if f.endswith(".json"):
                fp = os.path.join(path, f)
                try:
                    with open(fp, 'r') as file:
                        data = json.load(file)
                    
                    if data.get('id') == 'aliolo':
                        # Migration logic
                        old_prompt = data.get('prompt', 'What is this?')
                        if not old_prompt:
                            old_prompt = 'What is this?'
                        
                        # We want to replace single prompt with multi-lang prompts
                        # If it is exactly "What is this?" or similar, we translate it
                        if old_prompt.lower() in ['what is this?', 'what is this']:
                            data['prompts'] = ["UK: What is this?", "UA: Що це?"]
                        else:
                            # If it was something else, preserve it as UK and add generic UA
                            if not old_prompt.startswith('UK: '):
                                data['prompts'] = [f"UK: {old_prompt}", "UA: Що це?"]
                            else:
                                data['prompts'] = [old_prompt, "UA: Що це?"]
                        
                        # Remove old field
                        if 'prompt' in data:
                            del data['prompt']
                        
                        with open(fp, 'w') as file:
                            json.dump(data, file, indent=2)
                        count += 1
                except Exception as e:
                    print(f"Error updating {fp}: {e}")
    print(f"Updated {count} cards.")

if __name__ == "__main__":
    update_cards()
