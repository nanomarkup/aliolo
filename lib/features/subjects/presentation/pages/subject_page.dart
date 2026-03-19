import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_landing_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/sub_subject_page.dart';
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
      _filteredSubjects =
          _allDashboardSubjects.where((s) {
            final matchesName = s
                .getName(_currentTestingLang)
                .toLowerCase()
                .contains(query);
            final matchesAge =
                _selectedAgeFilter == 'all' || s.ageGroup == _selectedAgeFilter;

            // Collection filter
            bool matchesCollection = true;
            if (_collectionFilter == 'favorites') {
              matchesCollection = s.isOnDashboard;
            } else if (_collectionFilter == 'mine') {
              matchesCollection = s.ownerId == myId;
            } else if (_collectionFilter == 'public') {
              matchesCollection = s.isPublic;
            }

            // Hierarchy: Only show top-level subjects in dashboard unless searching
            final matchesHierarchy = query.isNotEmpty || s.parentId == null;

            return matchesName && matchesAge && matchesCollection && matchesHierarchy;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    final activePillars = pillars.toList();
    final isSearching = _searchController.text.isNotEmpty;

    return ListenableBuilder(
      listenable: Listenable.merge([
        _cardService,
        TranslationService(),
        ThemeService(),
        getIt<TestingLanguageService>(),
      ]),
      builder: (context, _) {
        final currentSessionColor = ThemeService().primaryColor;

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
                  getIt<TestingLanguageService>().activeLanguageCodes.map((l) {
                    return DropdownMenuItem(
                      value: l.toLowerCase(),
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
            if (isSearching)
              IconButton(
                icon: const Icon(Icons.school, color: appBarColor),
                onPressed: () {
                  _searchController.clear();
                  _applySearch();
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
                    if (_filteredSubjects.isEmpty)
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
                              final pillar = activePillars[index];
                              // Filter subjects by this pillar from the already-filtered list
                              final pillarSubjects =
                                  _filteredSubjects
                                      .where((s) => s.pillarId == pillar.id)
                                      .toList();

                              return _PillarGridTile(
                                pillar: pillar,
                                count: pillarSubjects.length,
                                languageCode: _currentTestingLang,
                                onTap:
                                    () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => PillarSubjectsPage(
                                              pillar: pillar,
                                              subjects: pillarSubjects,
                                              languageCode: _currentTestingLang,
                                              initialAgeFilter:
                                                  _selectedAgeFilter,
                                              initialCollectionFilter:
                                                  _collectionFilter,
                                            ),
                                      ),
                                    ),
                              );
                            }, childCount: activePillars.length),
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
                builder: (context) => SubSubjectPage(parentSubject: subject),
              ),
            );
          } else {
            final cards = await CardService().getCardsBySubject(subject.id);
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

class _PillarGridTile extends StatelessWidget {
  final Pillar pillar;
  final int count;
  final String languageCode;
  final VoidCallback onTap;

  const _PillarGridTile({
    required this.pillar,
    required this.count,
    required this.languageCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor();

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
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
                      '$count ${context.plural('subject', count)}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PillarSubjectsPage extends StatefulWidget {
  final Pillar pillar;
  final List<SubjectModel> subjects;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;

  const PillarSubjectsPage({
    super.key,
    required this.pillar,
    required this.subjects,
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
  List<SubjectModel> _filteredSubjects = [];
  bool _isLoading = true;
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
    // Fetch fresh subjects for this pillar (including sub-subjects)
    final results = await _cardService.getSubjectsByPillar(widget.pillar.id);
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
      _filteredSubjects =
          _allSubjects.where((s) {
            final matchesName = s
                .getName(widget.languageCode)
                .toLowerCase()
                .contains(query);
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

            // Hierarchy: Only show top-level subjects in pillar list unless searching
            final matchesHierarchy = query.isNotEmpty || s.parentId == null;

            return matchesName && matchesAge && matchesCollection && matchesHierarchy;
          }).toList();

      // Sort alphabetically by name
      _filteredSubjects.sort((a, b) => a.getName(widget.languageCode).toLowerCase().compareTo(b.getName(widget.languageCode).toLowerCase()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final pillarColor = widget.pillar.getColor();
    const appBarColor = Colors.white;

    return AlioloScrollablePage(
      title: Text(
        widget.pillar.getTranslatedName(widget.languageCode),
        style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
      ),
      appBarColor: pillarColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
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
                    child: IconButton(
                      icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
                      padding: EdgeInsets.zero,
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) =>
                                    SubjectEditPage(pillarId: widget.pillar.id),
                          ),
                        );
                        if (result == true) _loadData();
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
      slivers: [
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filteredSubjects.isEmpty)
          const SliverFillRemaining(
            child: Center(child: Text('No subjects found')),
          )
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
                );
              }, childCount: _filteredSubjects.length),
            ),
          ),
      ],
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
