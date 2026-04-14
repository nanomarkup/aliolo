import re
import json
import os

folder_id = "1c85e6e5-195e-4251-bbbd-b84637427977"
file_path = "scripts/sql/migration_data.sql"
out_script = "delete_cf_images.sh"

with open(file_path, "r") as f:
    content = f.read()

# 1. Find all subject IDs belonging to the Alphabets folder
subject_ids = set()
# Pattern to match subjects inserts: ('<subject_id>', <pillar>, '<owner>', <public>, '<date>', '<date>', '<age>', '<json>', '<folder_id>')
# Example: ('48d52b9d-329b-44be-95e4-c89c0d5e9fca', 6, 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac', 1, '2026-03-21T00:11:20.286917+00:00', '2026-03-18T20:51:45.184336+00:00', '0_6', '{...}', '1c85e6e5-195e-4251-bbbd-b84637427977')
# Let's just find lines with the folder_id
lines = content.split('\n')
for line in lines:
    if line.startswith("(") and folder_id in line:
        match = re.match(r"\('([a-z0-9\-]+)',", line)
        if match:
            # check if the last param is the folder_id
            if line.rstrip().endswith(f"'{folder_id}')") or line.rstrip().endswith(f"'{folder_id}'),"):
                subject_ids.add(match.group(1))

print(f"Found {len(subject_ids)} alphabet subjects.")

cf_delete_commands = []
new_lines = []

# 2. Process cards
# Cards look like: ('id', 'subject_id', level, 'owner_id', is_public, 'created_at', 'updated_at', 'test_mode', 'localized_data')
for line in lines:
    if line.startswith("(") and "{" in line and "}" in line:
        match = re.match(r"\('([a-z0-9\-]+)',\s*'([a-z0-9\-]+)',", line)
        if match:
            card_id = match.group(1)
            subject_id = match.group(2)
            
            if subject_id in subject_ids:
                # Find the JSON part
                # It's always the last parameter, inside single quotes
                json_match = re.search(r",\s*'(\{.*?\})'\)(,|;)$", line)
                if json_match:
                    json_str = json_match.group(1)
                    json_str = json_str.replace("''", "'") # SQL escaping
                    try:
                        data = json.loads(json_str)
                        modified = False
                        
                        for lang, lang_data in data.items():
                            if "image_urls" in lang_data:
                                for url in lang_data["image_urls"]:
                                    if "aliolo.com/storage/v1/object/public/card_images/" in url:
                                        # Extract path after card_images/
                                        path = url.split("card_images/")[1]
                                        cf_delete_commands.append(f"npx wrangler r2 object delete aliolo-media {path}")
                                del lang_data["image_urls"]
                                modified = True
                            if "image_url" in lang_data:
                                del lang_data["image_url"]
                                modified = True
                                
                        if modified:
                            new_json_str = json.dumps(data, ensure_ascii=False)
                            new_json_str = new_json_str.replace("'", "''")
                            # Replace the old json string with the new one
                            line = line[:json_match.start(1)] + new_json_str + line[json_match.end(1):]
                    except Exception as e:
                        print(f"Error parsing JSON for card {card_id}: {e}")
    new_lines.append(line)

with open(file_path, "w") as f:
    f.write('\n'.join(new_lines))
    
print(f"Updated {file_path}")

with open(out_script, "w") as f:
    f.write("#!/bin/bash\n")
    f.write("cd api\n")
    f.write("\n".join(cf_delete_commands))
    
os.chmod(out_script, 0o755)
print(f"Created {out_script} with {len(cf_delete_commands)} delete commands.")
