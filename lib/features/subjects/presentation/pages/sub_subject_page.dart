import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_landing_page.dart';

class SubSubjectPage extends StatefulWidget {
  final SubjectModel parentSubject;
  final String languageCode;

  const SubSubjectPage({
    super.key,
    required this.parentSubject,
    required this.languageCode,
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
  String _selectedAgeFilter = 'all';
  String _collectionFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadSubSubjects();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubSubjects() async {
    setState(() => _isLoading = true);
    final results = await _cardService.getSubSubjects(widget.parentSubject.id);
    if (mounted) {
      setState(() {
        _allSubSubjects = results;
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
        final matchesSearch = s.getName(lang).toLowerCase().contains(query);
        final matchesAge =
            _selectedAgeFilter == 'all' || s.ageGroup == _selectedAgeFilter;

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

  @override
  Widget build(BuildContext context) {
    final pillar = pillars.firstWhere(
      (p) => p.id == widget.parentSubject.pillarId,
      orElse: () => pillars.first,
    );
    final pillarColor = pillar.getColor();
    const appBarColor = Colors.white;
    final lang = widget.languageCode;

    return AlioloScrollablePage(
      title: Text(
        widget.parentSubject.getName(lang),
        style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
      ),
      appBarColor: pillarColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
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
                    ],
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 24),
            child: Row(
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
              ],
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pillarColor.withValues(alpha: 0.3)),
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
                      child: Text(
                        e.value,
                        style: const TextStyle(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
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

  const _SubjectListTile({
    required this.subject,
    required this.pillar,
    required this.languageCode,
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubSubjectPage(
                  parentSubject: subject,
                  languageCode: languageCode,
                ),
              ),
            );
          } else {
            final cards = await getIt<CardService>().getCardsBySubject(
              subject.id,
            );
            if (context.mounted) {
              Navigator.push(
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
                subject.type == 'math_engine'
                    ? Icons.calculate
                    : subject.type == 'folder'
                    ? Icons.folder
                    : pillar.getIconData(),
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
                      subject.type == 'math_engine'
                          ? 'Interactive • ${pillar.getTranslatedName(languageCode)}'
                          : subject.type == 'folder'
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
