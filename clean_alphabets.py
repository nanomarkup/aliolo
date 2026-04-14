import re
import json

folder_id = "1c85e6e5-195e-4251-bbbd-b84637427977"

with open("scripts/sql/migration_data.sql", "r") as f:
    lines = f.readlines()

subject_ids = set()
# Find subjects
for line in lines:
    if line.startswith("INSERT OR REPLACE INTO subjects") or line.startswith("('"):
        if folder_id in line and len(line.split(",")) > 3:
            # Try to extract subject ID. In migration_data.sql, subjects look like:
            # ('c6c33310-7a3f-4a5c-aef4-b37feb0662a4', 6, 'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac', 1, ...
            match = re.match(r"\('([a-z0-9\-]+)',[^,]+,\s*'([a-z0-9\-]+)'", line)
            if match and match.group(2) == folder_id:
                pass # wait, folder_id is the 3rd param ?
