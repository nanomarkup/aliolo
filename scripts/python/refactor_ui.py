import re

def process_subject_edit():
    file_path = 'lib/features/management/presentation/pages/subject_edit_page.dart'
    with open(file_path, 'r') as f:
        content = f.read()

    if "bool _showSidebar" not in content:
        content = re.sub(
            r'(bool _isSaving = false;)',
            r'\1\n  bool _showSidebar = false;',
            content
        )

    toggle_btn = """                    IconButton(
                      tooltip: 'Languages',
                      icon: Icon(_showSidebar ? Icons.last_page : Icons.language),
                      onPressed: () => setState(() => _showSidebar = !_showSidebar),
                    ),
                    backAction,"""
    
    content = content.replace("backAction,", toggle_btn)
    
    old_body_start = """          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth - 32;
                  final items = (availableWidth + 8) ~/ 62;
                  _itemsPerRow = items > 0 ? items : 1;

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildLangTile(
                          'global',
                          'GLB',
                          Icons.public,
                          'Global / Fallback',
                        ),
                        ...(() {
                          final langs = TranslationService()
                              .availableUILanguages
                              .map((l) => l.toLowerCase())
                              .toList();
                          langs.sort();
                          return langs.map((code) {
                            return _buildLangTile(
                              code,
                              code.toUpperCase(),
                              null,
                              TranslationService().getLanguageName(code),
                            );
                          });
                        })(),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              Form(
                key: _formKey,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildEditor(),
                ),
              ),
            ],
          ),"""

    new_body = """          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_showSidebar && isSmallScreen)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: _buildLangGrid(),
                        ),
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildEditor(),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              if (_showSidebar && !isSmallScreen)
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildLangGrid(),
                    ),
                  ),
                ),
            ],
          ),"""
          
    content = content.replace(old_body_start, new_body)

    lang_grid_method = """

  Widget _buildLangGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final items = (availableWidth + 8) ~/ 62;
        _itemsPerRow = items > 0 ? items : 1;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildLangTile(
              'global',
              'GLB',
              Icons.public,
              'Global / Fallback',
            ),
            ...(() {
              final langs = TranslationService()
                  .availableUILanguages
                  .map((l) => l.toLowerCase())
                  .toList();
              langs.sort();
              return langs.map((code) {
                return _buildLangTile(
                  code,
                  code.toUpperCase(),
                  null,
                  TranslationService().getLanguageName(code),
                );
              });
            })(),
          ],
        );
      },
    );
  }
}
"""
    # Remove the very last "}" and append the method
    content = content.rsplit('}', 1)[0] + lang_grid_method

    with open(file_path, 'w') as f:
        f.write(content)


def process_add_card():
    file_path = 'lib/features/management/presentation/pages/add_card_page.dart'
    with open(file_path, 'r') as f:
        content = f.read()

    if "bool _showSidebar" not in content:
        content = re.sub(
            r'(bool _isSaving = false;)',
            r'\1\n  bool _showSidebar = false;',
            content
        )

    toggle_btn = """                    IconButton(
                      tooltip: 'Languages',
                      icon: Icon(_showSidebar ? Icons.last_page : Icons.language),
                      onPressed: () => setState(() => _showSidebar = !_showSidebar),
                    ),
                    backAction,"""
    
    content = content.replace("backAction,", toggle_btn)

    old_body_start = """          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Tile width 54 + spacing 8 = 62. Total padding 16*2 = 32.
                    final availableWidth = constraints.maxWidth;
                    final items = (availableWidth + 8) ~/ 62;
                    _itemsPerRow = items > 0 ? items : 1;

                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildLangTile(
                            'global',
                            'GLB',
                            Icons.public,
                            'Global / Fallback',
                          ),
                          ...(() {
                            final langs = TranslationService()
                                .availableUILanguages
                                .map((l) => l.toLowerCase())
                                .toList();
                            langs.sort();
                            return langs.map((code) {
                              return _buildLangTile(
                                code,
                                code.toUpperCase(),
                                null,
                                TranslationService().getLanguageName(code),
                              );
                            });
                          })(),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: _buildEditor(),
                    ),
                  ),
                ),
              ],
            ),
          ),"""

    new_body = """          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_showSidebar && isSmallScreen)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildLangGrid(),
                          ),
                        const SizedBox(height: 32),
                        Form(
                          key: _formKey,
                          child: _buildEditor(),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
              if (_showSidebar && !isSmallScreen)
                Container(
                  width: 320,
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: _buildLangGrid(),
                    ),
                  ),
                ),
            ],
          ),"""
          
    content = content.replace(old_body_start, new_body)

    lang_grid_method = """

  Widget _buildLangGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final items = (availableWidth + 8) ~/ 62;
        _itemsPerRow = items > 0 ? items : 1;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildLangTile(
              'global',
              'GLB',
              Icons.public,
              'Global / Fallback',
            ),
            ...(() {
              final langs = TranslationService()
                  .availableUILanguages
                  .map((l) => l.toLowerCase())
                  .toList();
              langs.sort();
              return langs.map((code) {
                return _buildLangTile(
                  code,
                  code.toUpperCase(),
                  null,
                  TranslationService().getLanguageName(code),
                );
              });
            })(),
          ],
        );
      },
    );
  }
}
"""
    content = content.rsplit('}', 1)[0] + lang_grid_method

    with open(file_path, 'w') as f:
        f.write(content)

process_subject_edit()
process_add_card()
print("Done")
