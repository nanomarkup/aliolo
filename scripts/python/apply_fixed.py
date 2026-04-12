import os

file_path = 'lib/features/subjects/presentation/pages/subject_page.dart'
with open(file_path, 'r') as f:
    content = f.read()

def clean_block(block_path):
    with open(block_path, 'r') as f:
        block = f.read()
    return block

main_old = clean_block('main_block.txt')
pillar_old = clean_block('pillar_block.txt')
folder_old = clean_block('folder_block.txt')

def make_fixed(old_block):
    # Remove slivers: [
    # Remove SliverToBoxAdapter(
    # Change padding
    # Remove trailing ), ),
    lines = old_block.splitlines()
    # Find Padding line
    padding_line_idx = -1
    for i, line in enumerate(lines):
        if 'child: Padding(' in line or 'Padding(' in line:
            padding_line_idx = i
            break
    
    if padding_line_idx == -1: return None
    
    # We want from Padding to the second to last line
    new_lines = lines[padding_line_idx:]
    # Remove SliverToBoxAdapter indentation from all lines
    # Usually it's 2 or 4 spaces difference
    # Let's just find the common leading whitespace of the Padding line and remove it
    leading = new_lines[0][:new_lines[0].find('Padding')]
    
    final_lines = []
    for line in new_lines:
        if line.startswith(leading):
            final_lines.append(line[len(leading):])
        else:
            final_lines.append(line.lstrip())
            
    # Remove the last two closing braces/brackets if they belong to SliverToBoxAdapter and slivers list
    # The last line should be the closing of Row/Padding
    # pillar_block ends with ), ), ),
    # Let's just pop the last few lines until we reach the closing of Padding
    while final_lines and not final_lines[-1].strip().endswith('),'):
        final_lines.pop()
    
    # The block ends with ), ), which are for Row and Padding.
    # slivers: [ SliverToBoxAdapter( child: Padding( ... ), ), ]
    # So we want to keep until the Padding closing.
    
    res = "\n".join(final_lines)
    # Ensure it starts with Padding(
    if res.startswith("child: "): res = res[7:]
    
    # Update padding
    res = res.replace("const EdgeInsets.only(top: 16, bottom: 24)", "const EdgeInsets.fromLTRB(16, 16, 16, 24)")
    
    return f"fixedBody: {res},\nslivers: ["

main_new = make_fixed(main_old)
pillar_new = make_fixed(pillar_old)
folder_new = make_fixed(folder_old)

if main_new and main_old in content:
    content = content.replace(main_old, main_new)
    print("Main updated")

if pillar_new and pillar_old in content:
    content = content.replace(pillar_old, pillar_new)
    print("Pillar updated")

if folder_new and folder_old in content:
    content = content.replace(folder_old, folder_new)
    print("Folder updated")

with open(file_path, 'w') as f:
    f.write(content)
