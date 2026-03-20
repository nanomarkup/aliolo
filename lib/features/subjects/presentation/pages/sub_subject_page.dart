import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/features/management/presentation/pages/subject_edit_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_landing_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubSubjectPage extends StatefulWidget {
  final SubjectModel parentSubject;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;

  const SubSubjectPage({
    super.key,
    required this.parentSubject,
    required this.languageCode,
    this.initialAgeFilter = 'all',
    this.initialCollectionFilter = 'all',
  });

  @override
  State<SubSubjectPage> createState() => _SubSubjectPageState();
}

class _SubSubjectPageState extends State<SubSubjectPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _searchController = TextEditingController();
  List<SubjectModel> _allSubSubjects = [];
  List<SubjectModel> _filteredSubSubjects = [];
  bool _isLoading = true;
  late String _selectedAgeFilter;
  late String _collectionFilter;
  late SubjectModel _currentParentSubject;
  bool _hasUpdated = false;

  @override
  void initState() {
    super.initState();
    _selectedAgeFilter = widget.initialAgeFilter;
    _collectionFilter = widget.initialCollectionFilter;
    _currentParentSubject = widget.parentSubject;
    _loadSubSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubSubjects() async {
    setState(() => _isLoading = true);
    final results = await _cardService.getSubSubjects(_currentParentSubject.id);
    final updatedParent = await _cardService.getSubjectById(_currentParentSubject.id);
    
    if (mounted) {
      setState(() {
        _allSubSubjects = results;
        if (updatedParent != null) {
          _currentParentSubject = updatedParent;
          _hasUpdated = true;
        }
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final lang = widget.languageCode;
    final myId = _authService.currentUser?.serverId;

    setState(() {
      _filteredSubSubjects = _allSubSubjects.where((s) {
        final matchesSearch = s.matchesNameRecursive(query, lang, _allSubSubjects);
        final matchesAge = s.matchesAgeGroupRecursive(_selectedAgeFilter, _allSubSubjects);

        bool matchesCollection = true;
        if (_collectionFilter == 'favorites') {
          matchesCollection = s.isOnDashboard;
        } else if (_collectionFilter == 'mine') {
          matchesCollection = s.ownerId == myId;
        } else if (_collectionFilter == 'public') {
          matchesCollection = s.isPublic;
        }

        return matchesSearch && matchesAge && matchesCollection;
      }).toList();

      _filteredSubSubjects.sort((a, b) => a
          .getName(lang)
          .toLowerCase()
          .compareTo(b.getName(lang).toLowerCase()));
    });
  }

  void _confirmDeleteFolder() {
    if (_allSubSubjects.isNotEmpty) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Text(context.t('cannot_delete_folder')),
              content: Text(context.t('delete_subjects_first')),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.t('ok')),
                ),
              ],
            ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(context.t('delete_subject')),
            content: const Text('Delete this folder?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  await _cardService.deleteSubjectById(_currentParentSubject.id);
                  if (context.mounted) {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, true); // Go back to dashboard
                  }
                },
                child: Text(
                  context.t('delete'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pillar = pillars.firstWhere(
      (p) => p.id == _currentParentSubject.pillarId,
      orElse: () => pillars.first,
    );
    final pillarColor = pillar.getColor();
    const appBarColor = Colors.white;
    final lang = widget.languageCode;

    final isOwner = _currentParentSubject.ownerId == _authService.currentUser?.serverId;

    return AlioloScrollablePage(
      title: Text(
        _currentParentSubject.getName(lang),
        style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
      ),
      appBarColor: pillarColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context, _hasUpdated),
        ),
        if (isOwner) ...[
          IconButton(
            icon: const Icon(Icons.edit, color: appBarColor),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => SubjectEditPage(
                        existingSubject: _currentParentSubject,
                      ),
                ),
              );
              if (result == true) {
                _loadSubSubjects();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: appBarColor),
            onPressed: _confirmDeleteFolder,
          ),
        ],
      ],
      fixedBody: LayoutBuilder(
        builder: (context, constraints) {
          final isSmall = constraints.maxWidth < 600;

          if (isSmall) {
            return Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 24),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.t('search_subjects'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                    ),
                    onChanged: (_) => _applyFilters(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildCompactDropdown(
                          value: _collectionFilter,
                          items: {
                            'all': context.t('filter_all'),
                            'favorites': context.t('filter_favorites'),
                            'mine': context.t('filter_my_subjects'),
                            'public': context.t('filter_public'),
                          },
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _collectionFilter = val;
                                _applyFilters();
                              });
                            }
                          },
                          pillarColor: pillarColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCompactDropdown(
                          value: _selectedAgeFilter,
                          items: {
                            'all': context.t('age_all'),
                            '0_6': context.t('age_0_6'),
                            '7_14': context.t('age_7_14'),
                            '15_plus': context.t('age_15_plus'),
                          },
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedAgeFilter = val;
                                _applyFilters();
                              });
                            }
                          },
                          pillarColor: pillarColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        child: IconButton(
                          icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
                          padding: EdgeInsets.zero,
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SubjectEditPage(
                                      pillarId: _currentParentSubject.pillarId,
                                      initialAgeGroup: _selectedAgeFilter,
                                      initialParentId: _currentParentSubject.id,
                                    ),
                              ),
                            );
                            if (result == true) _loadSubSubjects();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: context.t('search_subjects'),
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        filled: true,
                        fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                      ),
                      onChanged: (_) => _applyFilters(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _buildCompactDropdown(
                      value: _collectionFilter,
                      items: {
                        'all': context.t('filter_all'),
                        'favorites': context.t('filter_favorites'),
                        'mine': context.t('filter_my_subjects'),
                        'public': context.t('filter_public'),
                      },
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _collectionFilter = val;
                            _applyFilters();
                          });
                        }
                      },
                      pillarColor: pillarColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _buildCompactDropdown(
                      value: _selectedAgeFilter,
                      items: {
                        'all': context.t('age_all'),
                        '0_6': context.t('age_0_6'),
                        '7_14': context.t('age_7_14'),
                        '15_plus': context.t('age_15_plus'),
                      },
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAgeFilter = val;
                            _applyFilters();
                          });
                        }
                      },
                      pillarColor: pillarColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: IconButton(
                      icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => SubjectEditPage(
                                  pillarId: _currentParentSubject.pillarId,
                                  initialAgeGroup: _selectedAgeFilter,
                                  initialParentId: _currentParentSubject.id,
                                ),
                          ),
                        );
                        if (result == true) _loadSubSubjects();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredSubSubjects.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text('No items found.'),
                ),
              )
              : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 32),
                itemCount: _filteredSubSubjects.length,
                itemBuilder: (context, index) {
                  final subject = _filteredSubSubjects[index];
                  return _SubjectListTile(
                    subject: subject,
                    pillar: pillar,
                    languageCode: lang,
                    initialAgeFilter: _selectedAgeFilter,
                    initialCollectionFilter: _collectionFilter,
                    onChanged: _loadSubSubjects,
                  );
                },
              ),
    );
  }

  Widget _buildCompactDropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
    required Color pillarColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: TextStyle(
            fontSize: 13,
            color:
                Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
          ),
          items:
              items.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SubjectListTile extends StatelessWidget {
  final SubjectModel subject;
  final Pillar pillar;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;
  final VoidCallback? onChanged;

  const _SubjectListTile({
    required this.subject,
    required this.pillar,
    required this.languageCode,
    required this.initialAgeFilter,
    required this.initialCollectionFilter,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor();
    final cardCount = subject.getCardCountForLanguage(languageCode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          if (subject.type == 'folder') {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubSubjectPage(
                  parentSubject: subject,
                  languageCode: languageCode,
                  initialAgeFilter: initialAgeFilter,
                  initialCollectionFilter: initialCollectionFilter,
                ),
              ),
            );
            if (result == true) {
              onChanged?.call();
            }
          } else {
            final cards = await getIt<CardService>().getCardsBySubject(
              subject.id,
            );
            if (context.mounted) {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => SubjectLandingPage(
                        subject: subject,
                        cards: cards,
                        languageCode: languageCode,
                      ),
                ),
              );
              if (result == true) {
                onChanged?.call();
              }
            }
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: pillarColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                subject.type == 'folder' ? Icons.folder : pillar.getIconData(),
                color: pillarColor,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.getName(languageCode),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      subject.type == 'folder'
                          ? '${pillar.getTranslatedName(languageCode)} • ${subject.childCount} ${context.plural('subject', subject.childCount)}'
                          : '${pillar.getTranslatedName(languageCode)} • $cardCount ${context.plural('card', cardCount)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
