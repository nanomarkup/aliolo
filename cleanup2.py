import re

with open("lib/features/subjects/presentation/pages/subject_landing_page.dart", "r") as f:
    content = f.read()

# Remove `bool _isSearchExpanded = false;`
content = re.sub(r"\s*bool _isSearchExpanded = false;", "", content)

# Remove `final isSmall = ...;` and `final filterRow = ...;` inside the build method
content = re.sub(r"\s*final isSmall = MediaQuery\.sizeOf\(context\)\.width < 600;\s*final filterRow = _currentCollection != null[\s\S]*?;\s*", "", content)

# We can also use simple string replacement if needed
# Need to find _buildLevelRangeWidgets
match = re.search(r"\s*List<Widget> _buildLevelRangeWidgets\s*\(Color pillarColor\) \{", content)
if match:
    idx = match.start()
    
    # Simple brace matching to remove the whole method
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

with open("lib/features/subjects/presentation/pages/subject_landing_page.dart", "w") as f:
    f.write(content)

print("Cleanup complete.")
