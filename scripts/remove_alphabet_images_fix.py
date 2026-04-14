import re
import json

folder_id = "1c85e6e5-195e-4251-bbbd-b84637427977"
file_path = "scripts/sql/migration_data.sql"

with open(file_path, "r") as f:
    content = f.read()

subject_ids = set()
lines = content.split('\n')
for line in lines:
    if line.startswith("(") and folder_id in line:
        match = re.match(r"\('([a-z0-9\-]+)',", line)
        if match:
            # check if the last param is the folder_id
            if line.rstrip().endswith(f"'{folder_id}')") or line.rstrip().endswith(f"'{folder_id}'),"):
                subject_ids.add(match.group(1))

print(f"Found {len(subject_ids)} alphabet subjects.")

new_lines = []

for line in lines:
    if line.startswith("(") and "{" in line and "}" in line:
        match = re.match(r"\('([a-z0-9\-]+)',\s*'([a-z0-9\-]+)',", line)
        if match:
            card_id = match.group(1)
            subject_id = match.group(2)
            
            if subject_id in subject_ids:
                json_match = re.search(r",\s*'(\{.*?\})'\)(,|;)$", line)
                if json_match:
                    json_str = json_match.group(1)
                    json_str = json_str.replace("''", "'") 
                    try:
                        data = json.loads(json_str)
                        modified = False
                        
                        for lang, lang_data in data.items():
                            if "image_urls" in lang_data:
                                del lang_data["image_urls"]
                                modified = True
                            if "image_url" in lang_data:
                                del lang_data["image_url"]
                                modified = True
                                
                        if modified:
                            new_json_str = json.dumps(data, ensure_ascii=False)
                            new_json_str = new_json_str.replace("'", "''")
                            line = line[:json_match.start(1)] + new_json_str + line[json_match.end(1):]
                    except Exception as e:
                        pass
    new_lines.append(line)

with open(file_path, "w") as f:
    f.write('\n'.join(new_lines))
    
print(f"Updated {file_path}")
