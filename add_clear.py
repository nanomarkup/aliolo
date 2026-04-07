import re

def process_file(filepath, update_method):
    with open(filepath, "r") as f:
        content = f.read()

    # Find TextField with _searchController
    # We want to add suffixIcon right after isDense: true,
    
    suffix_code = f"""
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: () {{
                                              _searchController.clear();
                                              {update_method}();
                                            }},
                                          )
                                        : null,"""
    
    # regex to match "isDense: true," inside InputDecoration
    # and we only want to replace it inside the search text fields
    
    # let's look for "prefixIcon: const Icon(Icons.search),\s*isDense: true,"
    pattern = re.compile(r"(prefixIcon:\s*const Icon\(Icons\.search\),\s*isDense:\s*true,)")
    
    def replacer(match):
        return match.group(1) + suffix_code
        
    new_content = pattern.sub(replacer, content)
    
    with open(filepath, "w") as f:
        f.write(new_content)

process_file("lib/features/subjects/presentation/pages/subject_page.dart", "_applySearch")
process_file("lib/features/subjects/presentation/pages/subject_landing_page.dart", "_applyFilters")

print("Added clear buttons.")
