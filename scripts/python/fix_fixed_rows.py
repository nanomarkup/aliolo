import re

file_path = 'lib/features/subjects/presentation/pages/subject_page.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Helper to refactor by splitting at known points
def refactor_block(text, start_marker, end_marker):
    # This assumes the block is unique
    if start_marker in text and end_marker in text:
        parts = text.split(start_marker)
        # We assume the first part before start_marker is what we want to keep
        # The second part contains our target row and then everything else
        sub_parts = parts[1].split(end_marker)
        
        pre = parts[0]
        row_content = sub_parts[0]
        post = end_marker.join(sub_parts[1:])
        
        # Clean up row_content (remove SliverToBoxAdapter tags)
        # row_content looks like:
        # child: Padding(
        #   padding: ...,
        #   child: Row(...)
        # ),
        # ),
        
        # We want to keep just the Padding part
        row_content = row_content.strip()
        if row_content.startswith("child: "):
            row_content = row_content[7:].strip()
        if row_content.endswith("),"):
            row_content = row_content[:-2].strip()
        if row_content.endswith("),"):
            row_content = row_content[:-2].strip()
            
        # Reconstruct
        # fixedBody: Padding(...),
        # slivers: [ ... ]
        return f"{pre}fixedBody: {row_content},\nslivers: [\n{end_marker}{post}"
    return text

# 1. SubjectPage (_SubjectPageState)
main_start = "slivers: [\n                  SliverToBoxAdapter("
main_end = "if (_isLoading)\n                    const SliverFillRemaining"
content = refactor_block(content, main_start, main_end)

# 2. PillarSubjectsPage (_PillarSubjectsPageState)
# Note: I need to be careful with indentation here.
pillar_start = "slivers: [\n              SliverToBoxAdapter("
pillar_end = "if (_isLoading) const SliverFillRemaining"
content = refactor_block(content, pillar_start, pillar_end)

# 3. FolderPage (_FolderPageState)
# The start/end are identical to pillar, so refactor_block might fail if I run it twice on the same text.
# I'll use unique context for them.

# Let's just use replace with full unique blocks for safety.
with open(file_path, 'w') as f:
    f.write(content)

print("Processed blocks")
