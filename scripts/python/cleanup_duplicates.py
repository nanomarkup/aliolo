import re

def fix_file(path):
    with open(path, 'r') as f:
        content = f.read()
    
    # This regex looks for the neutral grey borders we added and keeps them,
    # while removing the subsequent session-colored borders.
    # It assumes the grey ones come first because of how 'replace' works.
    
    # Pattern to find the block of grey borders and then the duplicate session ones
    pattern = re.compile(
        r'(border: OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(12\),\s*borderSide: BorderSide\(color: Colors\.grey\.withValues\(alpha: 0\.5\)\),\s*\),)'
        r'.*?'
        r'(enabledBorder: OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(12\),\s*borderSide: BorderSide\(color: Colors\.grey\.withValues\(alpha: 0\.5\)\),\s*\),)'
        r'.*?'
        r'(focusedBorder: OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(12\),\s*borderSide: BorderSide\(color: Colors\.grey\.withValues\(alpha: 0\.5\)\),\s*\),)'
        r'(.*?)'
        r'(border: OutlineInputBorder\(.*?\),)'
        r'(.*?)'
        r'(enabledBorder: OutlineInputBorder\(.*?\),)'
        r'(.*?)'
        r'(focusedBorder: OutlineInputBorder\(.*?\),)',
        re.DOTALL
    )
    
    def remove_duplicates(match):
        # Keep the first 3 (grey) and the intermediate content (suffixIcon etc), 
        # but remove the later 3 (session color)
        grey_border = match.group(1)
        grey_enabled = match.group(2)
        grey_focused = match.group(3)
        middle_part = match.group(4)
        # 5, 7, 9 are the duplicates we want to remove
        after_part = match.group(6) + match.group(8) + match.group(10)
        
        # We need to be careful about matching the specific session color blocks.
        # Let's just return the cleaned up version.
        return f"{grey_border}\n{grey_enabled}\n{grey_focused}\n{middle_part}\n{after_part}"

    # Actually, a simpler way might be to just search for the specific "currentSessionColor" blocks and remove them
    # if we already have the grey ones.
    
    new_content = content
    # Remove duplicates in SubjectPage
    new_content = re.sub(
        r'border: OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(12\),\s*borderSide: BorderSide\(\s*color: currentSessionColor.*?width: 2,\s*\),\s*\),',
        '', new_content, flags=re.DOTALL
    )
    # The above is too specific. Let's just target the ones using currentSessionColor or pillarColor inside InputDecorations that already have grey borders.
    
    # Let's try a different approach: read the file, and for each InputDecoration, if it has duplicate keys, keep the grey one.
    
    with open(path, 'w') as f:
        f.write(new_content)

# Refined approach: just use replace to remove the specific old blocks
def manual_fix():
    paths = [
        'lib/features/subjects/presentation/pages/subject_page.dart',
        'lib/features/subjects/presentation/pages/subject_landing_page.dart'
    ]
    
    for path in paths:
        with open(path, 'r') as f:
            content = f.read()
        
        # Remove the session color blocks that were left behind
        # SubjectPage variants
        content = re.sub(r'border: OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(12\),\s*borderSide: BorderSide\(\s*color: (currentSessionColor|pillarColor).*?\)\s*\),', '', content, flags=re.DOTALL)
        content = re.sub(r'enabledBorder: OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(12\),\s*borderSide: BorderSide\(\s*color: (currentSessionColor|pillarColor).*?\)\s*\),', '', content, flags=re.DOTALL)
        content = re.sub(r'focusedBorder: OutlineInputBorder\(\s*borderRadius: BorderRadius\.circular\(12\),\s*borderSide: BorderSide\(\s*color: (currentSessionColor|pillarColor).*?\)\s*\),', '', content, flags=re.DOTALL)
        
        with open(path, 'w') as f:
            f.write(content)

manual_fix()
print("Cleaned up duplicates")
