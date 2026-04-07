import re

with open("lib/features/subjects/presentation/pages/subject_landing_page.dart", "r") as f:
    content = f.read()

# Look for _buildLevelRangeWidgets function
match = re.search(r"List<Widget>\s*_buildLevelRangeWidgets\s*\(\s*Color\s*\w+\s*\)\s*\{", content)
if match:
    idx = match.start()
    
    count = 0
    in_string = False
    escape = False
    method_end = -1
    
    start_brace = content.find("{", idx)
    
    for i in range(start_brace, len(content)):
        if escape:
            escape = False
            continue
        c = content[i]
        if c == '\\':
            escape = True
        elif c == "'" or c == '"':
            if not in_string:
                in_string = c
            elif in_string == c:
                in_string = False
        elif not in_string:
            if c == '{':
                count += 1
            elif c == '}':
                count -= 1
                if count == 0:
                    method_end = i
                    break
    
    if method_end != -1:
        content = content[:idx] + content[method_end+1:]
        print("Removed _buildLevelRangeWidgets.")

with open("lib/features/subjects/presentation/pages/subject_landing_page.dart", "w") as f:
    f.write(content)

