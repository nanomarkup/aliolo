import re

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
            if c == '[':
                count += 1
            elif c == ']':
                count -= 1
                if count == 0:
                    return i
    return -1

with open("lib/features/subjects/presentation/pages/subject_landing_page.dart", "r") as f:
    content = f.read()

# Look for "if (isSmall) ...[" and the else branch
match = re.search(r"if\s*\(isSmall\)\s*\.\.\.\[\s*Row\(", content)
if match:
    idx = match.start()
    start_bracket = idx + match.group(0).find("[")
    mobile_bracket_end = balance_parens(content, start_bracket)
    
    else_match = re.search(r"\s*\]\s*else\s*\.\.\.\[", content[mobile_bracket_end-1:mobile_bracket_end+20])
    
    if else_match:
        else_bracket_start = mobile_bracket_end - 1 + else_match.start() + else_match.group().rfind("[")
        else_bracket_end = balance_parens(content, else_bracket_start)
        
        # We need the Row code itself inside the mobile bracket
        row_start = content.find("Row(", start_bracket)
        mobile_content = content[row_start:mobile_bracket_end].rstrip()
        
        # Reconstruct content
        new_content = content[:idx] + mobile_content + content[else_bracket_end+1:]
        
        with open("lib/features/subjects/presentation/pages/subject_landing_page.dart", "w") as f:
            f.write(new_content)
        print("Successfully replaced layout branch in subject_landing_page.dart")
    else:
        print("Could not find else branch")
else:
    print("Could not find if (isSmall)")
