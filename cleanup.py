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
            if c == '(':
                count += 1
            elif c == ')':
                count -= 1
                if count == 0:
                    return i
    return -1

with open("lib/features/subjects/presentation/pages/subject_page.dart", "r") as f:
    content = f.read()

indices = [m.start() for m in re.finditer(r"child:\s*isSmallScreen\s*\?\s*Row\(", content)]

for i, idx in reversed(list(enumerate(indices))):
    # Find start of mobile Row
    mobile_row_match = re.search(r"Row\(", content[idx:])
    mobile_row_start = idx + mobile_row_match.start()
    mobile_row_end = balance_parens(content, mobile_row_start)
    
    # The ternary branch ':' comes after mobile_row_end
    colon_match = re.search(r"\s*:\s*Row\(", content[mobile_row_end:])
    if not colon_match:
        print("Error finding colon branch")
        continue
    
    large_row_start = mobile_row_end + colon_match.start() + colon_match.group(0).find("Row(")
    large_row_end = balance_parens(content, large_row_start)
    
    mobile_row_code = content[mobile_row_start:mobile_row_end+1]
    
    # We want to inject the Source dropdown right after 'children: ['
    children_match = re.search(r"children:\s*\[", mobile_row_code)
    if not children_match:
        print("Error finding children:[")
        continue
        
    insert_pos = children_match.end()
    
    dropdown_code = """
                          if (!isSmallScreen) ...[
                            SizedBox(
                              width: 160,
                              child: _buildCompactDropdown(
                                value: _filters.collectionFilter,
                                items: {
                                  'all': context.t('filter_all'),
                                  'favorites': context.t('filter_favorites'),
                                  'mine': context.t('filter_my_subjects'),
                                  'public': context.t('filter_public_library'),
                                },
                                onChanged: (val) async {
                                  if (val != null) {
                                    setState(() {
                                      _filters = _filters.copyWith(collectionFilter: val);
                                      _applySearch();
                                    });
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setString('last_collection_filter', val);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],"""
                          
    new_mobile_row = mobile_row_code[:insert_pos] + dropdown_code + mobile_row_code[insert_pos:]
    
    # Replace the whole isSmallScreen ? ... : ... block
    content = content[:idx] + "child: " + new_mobile_row + content[large_row_end+1:]

with open("lib/features/subjects/presentation/pages/subject_page.dart", "w") as f:
    f.write(content)

print("Replacement complete.")
