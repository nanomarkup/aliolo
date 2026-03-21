import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/folder_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_landing_page.dart';
import 'package:aliolo/features/management/presentation/pages/subject_edit_page.dart';
import 'package:aliolo/data/services/feedback_service.dart';

import 'package:aliolo/features/feedback/presentation/pages/feedback_page.dart';

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final _cardService = getIt<CardService>();
  final _searchController = TextEditingController();
  final _authService = getIt<AuthService>();

  String _currentTestingLang = 'en';
  bool _isLangInitialized = false;

  List<SubjectModel> _allDashboardSubjects = [];
  List<FolderModel> _allDashboardFolders = [];
  List<SubjectModel> _allMatchingSubjects = [];
  List<SubjectModel> _filteredSubjects = [];
  bool _isLoading = true;
  String _selectedAgeFilter = 'all';
  String _collectionFilter = 'favorites'; // Default to favorites

  @override
  void initState() {
    super.initState();
    ThemeService().setSessionColor(ThemeService().primaryColor);
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    _initLanguage();
    _loadDashboard();
    _cardService.addListener(_loadDashboard);
  }

  @override
  void dispose() {
    getIt<AuthService>().removeListener(_onAuthChanged);
    _cardService.removeListener(_loadDashboard);
    _searchController.dispose();
    super.dispose();
  }

  void _initLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('last_testing_lang');
    final savedAgeFilter = prefs.getString('last_age_filter');
    final savedCollectionFilter = prefs.getString('last_collection_filter');

    if (mounted) {
      setState(() {
        if (savedLang != null) {
          _currentTestingLang = savedLang;
          _isLangInitialized = true;
        } else {
          final user = getIt<AuthService>().currentUser;
          if (user != null) {
            _currentTestingLang = user.defaultLanguage.toLowerCase();
            _isLangInitialized = true;
          }
        }
        if (savedAgeFilter != null) {
          _selectedAgeFilter = savedAgeFilter;
        }
        if (savedCollectionFilter != null) {
          _collectionFilter = savedCollectionFilter;
        }
      });
    }
    getIt<AuthService>().addListener(_onAuthChanged);
  }

  void _onAuthChanged() async {
    if (mounted && !_isLangInitialized) {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('last_testing_lang');
      if (savedLang != null) {
        setState(() {
          _currentTestingLang = savedLang;
          _isLangInitialized = true;
        });
        return;
      }

      final user = getIt<AuthService>().currentUser;
      if (user != null) {
        setState(() {
          _currentTestingLang = user.defaultLanguage.toLowerCase();
          _isLangInitialized = true;
        });
      }
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    await _cardService.getPillars();
    final subjects = await _cardService.getDashboardSubjects();
    final folders = await _cardService.getAllFolders();

    if (mounted) {
      final Set<String> detectedLangs = {};
      for (var s in subjects) {
        // Scan subject names/descriptions
        detectedLangs.addAll(s.localizedData.keys.map((k) => k.toLowerCase()));

        // Scan nested cards
        if (s.rawCards != null) {
          for (var c in s.rawCards!) {
            final locData = c['localized_data'] as Map?;
            if (locData != null) {
              detectedLangs.addAll(
                locData.keys.map((k) => k.toString().toLowerCase()),
              );
            }
          }
        }
      }

      // Filter out 'global' and other non-language markers
      detectedLangs.remove('global');
      detectedLangs.remove('default');

      if (detectedLangs.isNotEmpty) {
        getIt<TestingLanguageService>().addActiveLanguages(
          detectedLangs.toList(),
        );
      }

      final prefs = await SharedPreferences.getInstance();
      final hasSavedCollection = prefs.containsKey('last_collection_filter');

      setState(() {
        _allDashboardSubjects = subjects;
        _allDashboardFolders = folders;
        // Smart default: if no favorites AND no saved preference, show public subjects
        if (!hasSavedCollection &&
            _allDashboardSubjects.where((s) => s.isOnDashboard).isEmpty) {
          _collectionFilter = 'public';
        }
        _applySearch();
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    final query = _searchController.text.toLowerCase();
    final myId = getIt<AuthService>().currentUser?.serverId;

    setState(() {
      // 1. All subjects that pass the basic filters (Pillar check uses this)
      _allMatchingSubjects = _allDashboardSubjects.where((s) {
        final matchesName = s.getName(_currentTestingLang).toLowerCase().contains(query);
        final matchesAge = _selectedAgeFilter == 'all' || s.ageGroup == _selectedAgeFilter;

        bool matchesCollection = true;
        if (_collectionFilter == 'mine') {
          matchesCollection = s.ownerId == myId;
        } else if (_collectionFilter == 'public') {
          matchesCollection = s.isPublic;
        } else if (_collectionFilter == 'favorites') {
          matchesCollection = true;
        }

        return matchesName && matchesAge && matchesCollection;
      }).toList();

      // 2. Visible subjects (The actual list/grid uses this)
      _filteredSubjects =
          _allMatchingSubjects.where((s) {
            // Hierarchy: Only show subjects that are NOT in a folder on dashboard unless searching
            final matchesHierarchy = query.isNotEmpty || s.folderId == null;
            return matchesHierarchy;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _cardService,
        TranslationService(),
        ThemeService(),
        getIt<TestingLanguageService>(),
      ]),
      builder: (context, _) {
        final isSearching = _searchController.text.isNotEmpty;
        final currentSessionColor = ThemeService().primaryColor;

        final activeCodes = getIt<TestingLanguageService>().activeLanguageCodes
            .map((l) => l.toLowerCase())
            .toSet();
        
        // Safety: Ensure current language is in the list
        if (!activeCodes.contains(_currentTestingLang)) {
          activeCodes.add(_currentTestingLang);
        }

        return AlioloScrollablePage(
          title: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currentTestingLang,
              dropdownColor: currentSessionColor,
              icon: const Icon(Icons.language, color: appBarColor, size: 20),
              style: const TextStyle(
                color: appBarColor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              items:
                  activeCodes.map((l) {
                    return DropdownMenuItem(
                      value: l,
                      child: Text(
                        getIt<TestingLanguageService>().getLanguageName(l),
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }).toList(),
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _currentTestingLang = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('last_testing_lang', val);
                  _applySearch();
                }
              },
            ),
          ),
          appBarColor: currentSessionColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.school, color: appBarColor),
              onPressed: () {
                if (isSearching) {
                  _searchController.clear();
                  _applySearch();
                } else {
                  _loadDashboard();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardPage(),
                    ),
                  ),
            ),
            IconButton(
              icon: ValueListenableBuilder<bool>(
                valueListenable: getIt<FeedbackService>().pendingNotifications,
                builder: (context, hasNotif, _) {
                  return Badge(
                    isLabelVisible: hasNotif,
                    backgroundColor: Colors.amber,
                    child: const Icon(Icons.person, color: appBarColor),
                  );
                },
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfilePage()),
                );
                _loadDashboard();
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  ),
            ),
          ],
          fixedBody: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;

              if (isSmall) {
                // Mobile: Stacked
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 24),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: context.t('search_subjects'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon:
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _searchController,
                                builder:
                                    (context, value, _) =>
                                        value.text.isNotEmpty
                                            ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _searchController.clear();
                                                _applySearch();
                                              },
                                            )
                                            : const SizedBox.shrink(),
                              ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).cardColor.withValues(alpha: 0.5),
                        ),
                        onChanged: (_) => _applySearch(),
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
                              onChanged: (val) async {
                                if (val != null) {
                                  setState(() {
                                    _collectionFilter = val;
                                    _applySearch();
                                  });
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setString(
                                    'last_collection_filter',
                                    val,
                                  );
                                }
                              },
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
                              onChanged: (val) async {
                                if (val != null) {
                                  setState(() {
                                    _selectedAgeFilter = val;
                                    _applySearch();
                                  });
                                  final prefs =
                                      await SharedPreferences.getInstance();
                                  await prefs.setString('last_age_filter', val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }

              // Desktop: Single row
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
                          suffixIcon:
                              ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _searchController,
                                builder:
                                    (context, value, _) =>
                                        value.text.isNotEmpty
                                            ? IconButton(
                                              icon: const Icon(Icons.clear),
                                              onPressed: () {
                                                _searchController.clear();
                                                _applySearch();
                                              },
                                            )
                                            : const SizedBox.shrink(),
                              ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          filled: true,
                          fillColor: Theme.of(
                            context,
                          ).cardColor.withValues(alpha: 0.5),
                        ),
                        onChanged: (_) => _applySearch(),
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
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _collectionFilter = val;
                              _applySearch();
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('last_collection_filter', val);
                          }
                        },
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
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() {
                              _selectedAgeFilter = val;
                              _applySearch();
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('last_age_filter', val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          slivers:
              _isLoading
                  ? [
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ]
                  : [
                    if (_allMatchingSubjects.isEmpty && _allDashboardFolders.isEmpty)
                      const SliverFillRemaining(
                        child: Center(child: Text('No subjects found')),
                      )
                    else if (isSearching)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 0),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final subject = _filteredSubjects[index];
                            final pillar = pillars.firstWhere(
                              (p) => p.id == subject.pillarId,
                            );
                            return _SubjectListTile(
                              subject: subject,
                              pillar: pillar,
                              languageCode: _currentTestingLang,
                              initialAgeFilter: _selectedAgeFilter,
                              initialCollectionFilter: _collectionFilter,
                              onChanged: _loadDashboard,
                            );
                          }, childCount: _filteredSubjects.length),
                        ),
                      )
                    else
                      SliverLayoutBuilder(
                        builder: (context, constraints) {
                          final crossAxisCount =
                              constraints.crossAxisExtent < 600 ? 1 : 2;
                          return SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  crossAxisSpacing: 24,
                                  mainAxisSpacing: 24,
                                  childAspectRatio:
                                      crossAxisCount == 1 ? 1.8 : 1.4,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final pillar = pillars[index];
                              
                              final totalPillarSubjects = _allDashboardSubjects
                                  .where((s) => s.pillarId == pillar.id)
                                  .toList();
                              final matchingPillarSubjects = _allMatchingSubjects
                                  .where((s) => s.pillarId == pillar.id)
                                  .toList();

                              final folderCount = _allDashboardFolders
                                  .where((f) => f.pillarId == pillar.id)
                                  .length;

                              return _PillarGridTile(
                                pillar: pillar,
                                subjectCount: matchingPillarSubjects.length,
                                totalSubjectCount: totalPillarSubjects.length,
                                folderCount: folderCount,
                                languageCode: _currentTestingLang,
                                onTap: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => PillarSubjectsPage(
                                            pillar: pillar,
                                            subjects: matchingPillarSubjects,
                                            allPillarSubjects: totalPillarSubjects,
                                            languageCode: _currentTestingLang,
                                            initialAgeFilter: _selectedAgeFilter,
                                            initialCollectionFilter: _collectionFilter,
                                          ),
                                    ),
                                  );

                                  if (result is Map) {
                                    setState(() {
                                      _selectedAgeFilter = result['ageFilter'] ?? _selectedAgeFilter;
                                      _collectionFilter = result['collectionFilter'] ?? _collectionFilter;
                                    });
                                    if (result['hasUpdated'] == true) {
                                      _loadDashboard();
                                    } else {
                                      _applySearch();
                                    }
                                  }
                                },
                              );
                            }, childCount: pillars.length),
                          );
                        },
                      ),
                  ],
        );
      },
    );
  }

  Widget _buildCompactDropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
            fontSize: 14,
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
    final isOwner = subject.ownerId == getIt<AuthService>().currentUser?.serverId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final cards = await CardService().getCardsBySubject(subject.id);
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
              Icon(pillar.getIconData(), color: pillarColor),
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
                      '${pillar.getTranslatedName(languageCode)} • $cardCount ${context.plural('card', cardCount)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (isOwner)
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubjectEditPage(
                          existingSubject: subject,
                        ),
                      ),
                    );
                    if (result == true) onChanged?.call();
                  },
                ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillarGridTile extends StatelessWidget {
  final Pillar pillar;
  final int subjectCount;
  final int totalSubjectCount;
  final int folderCount;
  final String languageCode;
  final VoidCallback onTap;

  const _PillarGridTile({
    required this.pillar,
    required this.subjectCount,
    required this.totalSubjectCount,
    required this.folderCount,
    required this.languageCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor();
    final bool isEmpty = subjectCount == 0 && folderCount == 0;

    return Opacity(
      opacity: isEmpty ? 0.5 : 1.0,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isEmpty ? 1 : 4,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  pillarColor,
                  pillarColor.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Icon(
                    pillar.getIconData(),
                    size: 120,
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(pillar.getIconData(), color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              pillar.getTranslatedName(languageCode),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        pillar.getTranslatedDescription(languageCode),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        subjectCount == totalSubjectCount
                            ? '$totalSubjectCount ${context.plural('subject', totalSubjectCount)}'
                            : '$subjectCount / $totalSubjectCount ${context.plural('subject', totalSubjectCount)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: subjectCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PillarSubjectsPage extends StatefulWidget {
  final Pillar pillar;
  final List<SubjectModel> subjects;
  final List<SubjectModel> allPillarSubjects;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;

  const PillarSubjectsPage({
    super.key,
    required this.pillar,
    required this.subjects,
    required this.allPillarSubjects,
    required this.languageCode,
    required this.initialAgeFilter,
    required this.initialCollectionFilter,
  });

  @override
  State<PillarSubjectsPage> createState() => _PillarSubjectsPageState();
}

class _PillarSubjectsPageState extends State<PillarSubjectsPage> {
  final _searchController = TextEditingController();
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();

  late List<SubjectModel> _allSubjects;
  late List<FolderModel> _allFolders;
  List<SubjectModel> _filteredSubjects = [];
  List<SubjectModel> _matchingSubjectsRecursive = [];
  List<FolderModel> _filteredFolders = [];
  bool _isLoading = true;
  bool _hasUpdated = false;
  late String _selectedAgeFilter;
  late String _collectionFilter;

  @override
  void initState() {
    super.initState();
    _selectedAgeFilter = widget.initialAgeFilter;
    _collectionFilter = widget.initialCollectionFilter;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final subjects = await _cardService.getSubjectsByPillar(widget.pillar.id, rootOnly: false);
    final folders = await _cardService.getFoldersByPillar(widget.pillar.id);
    if (mounted) {
      setState(() {
        _allSubjects = subjects;
        _allFolders = folders;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final myId = _authService.currentUser?.serverId;

    setState(() {
      _filteredFolders = _allFolders; // File system: folders always visible

      final allMatching = _allSubjects.where((s) {
        final matchesName = s.getName(widget.languageCode).toLowerCase().contains(query);
        final matchesAge = _selectedAgeFilter == 'all' || s.ageGroup == _selectedAgeFilter;

        bool matchesCollection = true;
        if (_collectionFilter == 'mine') {
          matchesCollection = s.ownerId == myId;
        } else if (_collectionFilter == 'public') {
          matchesCollection = s.isPublic;
        } else if (_collectionFilter == 'favorites') {
          matchesCollection = true;
        }

        return matchesName && matchesAge && matchesCollection;
      }).toList();

      _matchingSubjectsRecursive = allMatching;

      _filteredSubjects = allMatching.where((s) => s.folderId == null).toList();

      // Sort alphabetically
      _filteredFolders.sort((a, b) => a.getName(widget.languageCode).toLowerCase().compareTo(b.getName(widget.languageCode).toLowerCase()));
      _filteredSubjects.sort((a, b) => a.getName(widget.languageCode).toLowerCase().compareTo(b.getName(widget.languageCode).toLowerCase()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final pillarColor = widget.pillar.getColor();
    const appBarColor = Colors.white;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: AlioloScrollablePage(
        title: Text(
          widget.pillar.getTranslatedName(widget.languageCode),
          style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
        ),
        appBarColor: pillarColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: appBarColor),
            onPressed: () => Navigator.pop(context, {
              'hasUpdated': _hasUpdated,
              'ageFilter': _selectedAgeFilter,
              'collectionFilter': _collectionFilter,
            }),
          ),
        ],
        fixedBody: Builder(
        builder: (context) {
          final isSmall = MediaQuery.of(context).size.width < 600;

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
                      fillColor: Theme.of(
                        context,
                      ).cardColor.withValues(alpha: 0.5),
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
                        fillColor: Theme.of(
                          context,
                        ).cardColor.withValues(alpha: 0.5),
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
                      padding: EdgeInsets.zero,
                      onSelected: (value) async {
                        bool? result;
                        if (value == 'subject') {
                          result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubjectEditPage(
                                pillarId: widget.pillar.id,
                                initialAgeGroup: _selectedAgeFilter,
                              ),
                            ),
                          );
                        } else if (value == 'folder') {
                          result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubjectEditPage(
                                pillarId: widget.pillar.id,
                                isFolderMode: true,
                              ),
                            ),
                          );
                        }
                        if (result == true) _loadData();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'subject',
                          child: ListTile(
                            leading: Icon(Icons.description, color: pillarColor),
                            title: Text(context.t('add_subject')),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'folder',
                          child: ListTile(
                            leading: Icon(Icons.folder, color: pillarColor),
                            title: Text(context.t('add_folder')),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
      slivers: [
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filteredFolders.isEmpty && _filteredSubjects.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No items found')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index < _filteredFolders.length) {
                  final folder = _filteredFolders[index];
                  
                  final matchingInFolder = _matchingSubjectsRecursive.where((s) => s.folderId == folder.id).toList();
                  final totalInFolder = folder.childCount;

                  return _FolderListTile(
                    folder: folder,
                    matchingCount: matchingInFolder.length,
                    totalCount: totalInFolder,
                    pillar: widget.pillar,
                    languageCode: widget.languageCode,
                    initialAgeFilter: _selectedAgeFilter,
                    initialCollectionFilter: _collectionFilter,
                    onChanged: _loadData,
                    onFilterChanged: (age, collection) {
                      setState(() {
                        _selectedAgeFilter = age;
                        _collectionFilter = collection;
                        _applyFilters();
                      });
                    },
                  );
                }
                final subject = _filteredSubjects[index - _filteredFolders.length];
                return _SubjectListTile(
                  subject: subject,
                  pillar: widget.pillar,
                  languageCode: widget.languageCode,
                  initialAgeFilter: _selectedAgeFilter,
                  initialCollectionFilter: _collectionFilter,
                  onChanged: _loadData,
                );
              }, childCount: _filteredFolders.length + _filteredSubjects.length),
            ),
          ),
      ],
    ),
  );
}

  Widget _buildCompactDropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
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

class FolderPage extends StatefulWidget {
  final FolderModel folder;
  final Pillar pillar;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;

  const FolderPage({
    super.key,
    required this.folder,
    required this.pillar,
    required this.languageCode,
    required this.initialAgeFilter,
    required this.initialCollectionFilter,
  });

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  final _searchController = TextEditingController();
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();

  List<SubjectModel> _allSubjects = [];
  List<SubjectModel> _filteredSubjects = [];
  bool _isLoading = true;
  late String _selectedAgeFilter;
  late String _collectionFilter;
  bool _hasUpdated = false;

  @override
  void initState() {
    super.initState();
    _selectedAgeFilter = widget.initialAgeFilter;
    _collectionFilter = widget.initialCollectionFilter;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await _cardService.getSubjectsByPillar(widget.pillar.id, folderId: widget.folder.id);
    if (mounted) {
      setState(() {
        _allSubjects = results;
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final myId = _authService.currentUser?.serverId;

    setState(() {
      _filteredSubjects = _allSubjects.where((s) {
        final matchesName = s.getName(widget.languageCode).toLowerCase().contains(query);
        final matchesAge = _selectedAgeFilter == 'all' || s.ageGroup == _selectedAgeFilter;

        bool matchesCollection = true;
        if (_collectionFilter == 'mine') {
          matchesCollection = s.ownerId == myId;
        } else if (_collectionFilter == 'public') {
          matchesCollection = s.isPublic;
        } else if (_collectionFilter == 'favorites') {
          matchesCollection = true;
        }

        return matchesName && matchesAge && matchesCollection;
      }).toList();

      _filteredSubjects.sort((a, b) => a.getName(widget.languageCode).toLowerCase().compareTo(b.getName(widget.languageCode).toLowerCase()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final pillarColor = widget.pillar.getColor();
    const appBarColor = Colors.white;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: AlioloScrollablePage(
        title: Text(
          widget.folder.getName(widget.languageCode),
          style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
        ),
        appBarColor: pillarColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: appBarColor),
            onPressed: () => Navigator.pop(context, {
              'hasUpdated': _hasUpdated,
              'ageFilter': _selectedAgeFilter,
              'collectionFilter': _collectionFilter,
            }),
          ),
        ],
        fixedBody: Builder(
          builder: (context) {
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                        ),
                        onChanged: (_) => _applyFilters(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 48,
                      child: PopupMenuButton<String>(
                        icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
                        padding: EdgeInsets.zero,
                        onSelected: (value) async {
                          bool? result;
                          if (value == 'subject') {
                            result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SubjectEditPage(
                                  pillarId: widget.pillar.id,
                                  folderId: widget.folder.id,
                                  initialAgeGroup: _selectedAgeFilter,
                                ),
                              ),
                            );
                          } else if (value == 'folder') {
                            result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SubjectEditPage(
                                  pillarId: widget.pillar.id,
                                  isFolderMode: true,
                                ),
                              ),
                            );
                          }
                          if (result == true) {
                            _loadData();
                            _hasUpdated = true;
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'subject',
                            child: ListTile(
                              leading: Icon(Icons.description, color: pillarColor),
                              title: Text(context.t('add_subject')),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          PopupMenuItem(
                            value: 'folder',
                            child: ListTile(
                              leading: Icon(Icons.folder, color: pillarColor),
                              title: Text(context.t('add_folder')),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
        slivers: [
          if (_isLoading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_filteredSubjects.isEmpty)
            const SliverFillRemaining(child: Center(child: Text('No subjects found')))
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final subject = _filteredSubjects[index];
                  return _SubjectListTile(
                    subject: subject,
                    pillar: widget.pillar,
                    languageCode: widget.languageCode,
                    initialAgeFilter: _selectedAgeFilter,
                    initialCollectionFilter: _collectionFilter,
                    onChanged: () {
                      _loadData();
                      _hasUpdated = true;
                    },
                  );
                }, childCount: _filteredSubjects.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _FolderListTile extends StatelessWidget {
  final FolderModel folder;
  final int matchingCount;
  final int totalCount;
  final Pillar pillar;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;
  final VoidCallback? onChanged;
  final Function(String age, String collection)? onFilterChanged;

  const _FolderListTile({
    required this.folder,
    required this.matchingCount,
    required this.totalCount,
    required this.pillar,
    required this.languageCode,
    required this.initialAgeFilter,
    required this.initialCollectionFilter,
    this.onChanged,
    this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor();
    final isOwner = folder.ownerId == getIt<AuthService>().currentUser?.serverId;
    final bool isEmpty = matchingCount == 0;

    return Opacity(
      opacity: isEmpty ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FolderPage(
                  folder: folder,
                  pillar: pillar,
                  languageCode: languageCode,
                  initialAgeFilter: initialAgeFilter,
                  initialCollectionFilter: initialCollectionFilter,
                ),
              ),
            );
            if (result is Map) {
              onFilterChanged?.call(
                result['ageFilter'] ?? initialAgeFilter,
                result['collectionFilter'] ?? initialCollectionFilter,
              );
              if (result['hasUpdated'] == true) onChanged?.call();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: pillarColor.withValues(alpha: 0.2), width: 1.5),
            ),
            child: Row(
              children: [
                Icon(Icons.folder, color: pillarColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        folder.getName(languageCode),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        matchingCount == totalCount
                            ? '${pillar.getTranslatedName(languageCode)} • $totalCount ${context.plural('subject', totalCount)}'
                            : '${pillar.getTranslatedName(languageCode)} • $matchingCount / $totalCount ${context.plural('subject', totalCount)}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                          fontWeight: matchingCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.grey, size: 20),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SubjectEditPage(
                            existingFolder: folder,
                            isFolderMode: true,
                          ),
                        ),
                      );
                      if (result == true) onChanged?.call();
                    },
                  ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
