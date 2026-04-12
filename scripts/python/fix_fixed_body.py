import re

file_path = 'lib/features/subjects/presentation/pages/subject_page.dart'
with open(file_path, 'r') as f:
    content = f.read()

# Replace starting tags
content = re.sub(
    r'slivers:\s*\[\s*SliverToBoxAdapter\(\s*child:\s*Padding\(',
    r'fixedBody: Padding(',
    content
)

# Replace ending tags before 'if (_isLoading)'
content = re.sub(
    r'(\s*)\],\n\s*\),\n\s*\),\n\s*\),\n\s*if \(_isLoading\)',
    r'\1],\n\1  ),\n\1),\nslivers: [\n\1if (_isLoading)',
    content
)

# Also there might be single line variants
content = re.sub(
    r'(\s*)\],\n\s*\),\n\s*\),\n\s*\),\n\s*if \(_isLoading\) const SliverFillRemaining',
    r'\1],\n\1  ),\n\1),\nslivers: [\n\1if (_isLoading) const SliverFillRemaining',
    content
)

with open(file_path, 'w') as f:
    f.write(content)

print("Done")
