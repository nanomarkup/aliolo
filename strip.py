import re

with open("lib/features/subjects/presentation/pages/subject_landing_page.dart", "r") as f:
    content = f.read()

# Remove isSmall and filterRow definition in LayoutBuilder
match = re.search(r"\s*final isSmall = constraints\.maxWidth < 600;\s*final filterRow =\s*_currentCollection != null\s*\? Row\(", content)

if match:
    idx = match.start()
    
    def balance_parens(text, start_index):
        count = 0
        in_string = False
        escape = False
        for i in range(start_index, len(text)):
            if escape:
                escape = False
                continue
            c = text[i]
            if c == '\\':
                escape = True
            elif c == "'" or c == '"':
                if not in_string:
                    in_string = c
                elif in_string == c:
                    in_string = False
            elif not in_string:
                if c == '(':
                    count += 1
                elif c == ')':
                    count -= 1
                    if count == 0:
                        return i
        return -1
    
    row_start = match.end() - 4 # index of Row(
    row_end = balance_parens(content, row_start)
    
    # After Row() there's : const SizedBox.shrink();
    colon_match = re.search(r"\s*:\s*const SizedBox\.shrink\(\);", content[row_end:])
    
    if colon_match:
        full_end = row_end + colon_match.end()
        content = content[:idx] + content[full_end:]
        print("Removed isSmall and filterRow variables.")
    else:
        print("Could not find colon match")

# Remove _buildLevelRangeWidgets if it exists
match = re.search(r"\s*List<Widget> _buildLevelRangeWidgets\s*\(Color pillarColor\) \{", content)
if match:
    idx = match.start()
    start_brace = content.find("{", idx)
    
    count = 0
    in_string = False
    escape = False
    method_end = -1
    
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

