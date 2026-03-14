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
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/testing/presentation/pages/test_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_landing_page.dart';
import 'package:aliolo/features/management/presentation/pages/subject_edit_page.dart';

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final _cardService = getIt<CardService>();
  final _searchController = TextEditingController();
  late String _currentTestingLang = 'en';
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

  void _initLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('last_testing_lang');

    if (mounted) {
      if (savedLang != null) {
        setState(() {
          _currentTestingLang = savedLang;
          _isLangInitialized = true;
        });
      } else {
        final user = getIt<AuthService>().currentUser;
        if (user != null) {
          setState(() {
            _currentTestingLang = user.defaultLanguage.toLowerCase();
            _isLangInitialized = true;
          });
        }
      }
    }
    getIt<AuthService>().addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    getIt<AuthService>().removeListener(_onAuthChanged);
    _cardService.removeListener(_loadDashboard);
    _searchController.dispose();
    super.dispose();
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
        if (s.rawCards != null) {
          for (var c in s.rawCards!) {
            final prompts = c['prompts'] as Map?;
            final answers = c['answers'] as Map?;
            if (prompts != null) {
              detectedLangs.addAll(
                prompts.keys.map((k) => k.toString().toLowerCase()),
              );
            }
            if (answers != null) {
              detectedLangs.addAll(
                answers.keys.map((k) => k.toString().toLowerCase()),
              );
            }
          }
        }
      }

      if (detectedLangs.isNotEmpty) {
        getIt<TestingLanguageService>().addActiveLanguages(
          detectedLangs.toList(),
        );
      }

      setState(() {
        _allDashboardSubjects = subjects;
        // Smart default: if no favorites, show public subjects
        if (_allDashboardSubjects.where((s) => s.isOnDashboard).isEmpty) {
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

            return matchesName && matchesAge && matchesCollection;
          }).toList();

      // Hardcoded sort by name
      _filteredSubjects.sort(
        (a, b) => a
            .getName(_currentTestingLang)
            .toLowerCase()
            .compareTo(b.getName(_currentTestingLang).toLowerCase()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    final currentSessionColor = ThemeService().sessionColorNotifier.value;
    final isSearching = _searchController.text.isNotEmpty;

    final rawActiveLangs =
        getIt<TestingLanguageService>().activeLanguageCodes
            .map((l) => l.toLowerCase())
            .toSet();
    final List<String> activeLangs = rawActiveLangs.toList()..sort();
    if (!activeLangs.contains(_currentTestingLang.toLowerCase())) {
      activeLangs.add(_currentTestingLang.toLowerCase());
      activeLangs.sort();
    }

    final activePillarIds = _filteredSubjects.map((s) => s.pillarId).toSet();
    final activePillars =
        pillars.where((p) => activePillarIds.contains(p.id)).toList();
    activePillars.sort(
      (a, b) => pillars.indexOf(a).compareTo(pillars.indexOf(b)),
    );

    return ListenableBuilder(
      listenable: Listenable.merge([
        TranslationService(),
        getIt<TestingLanguageService>(),
        _cardService,
      ]),
      builder: (context, _) {
        return AlioloScrollablePage(
          title: DropdownButton<String>(
            value: _currentTestingLang.toLowerCase(),
            dropdownColor: currentSessionColor,
            style: const TextStyle(color: appBarColor, fontSize: 22),
            underline: const SizedBox(),
            icon: const Icon(Icons.arrow_drop_down, color: appBarColor),
            items:
                activeLangs
                    .map(
                      (l) => DropdownMenuItem(
                        value: l.toLowerCase(),
                        child: Text(
                          getIt<TestingLanguageService>().getLanguageName(l),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (val) async {
              if (val != null) {
                setState(() => _currentTestingLang = val.toLowerCase());
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('last_testing_lang', val.toLowerCase());
                _applySearch();
              }
            },
          ),
          appBarColor: currentSessionColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.school, color: appBarColor),
              onPressed: () => _loadDashboard(),
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
              icon: const Icon(Icons.person, color: appBarColor),

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
          fixedBody:
              _isLoading
                  ? null
                  : Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 24),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
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
                          flex: 1,
                          child: _buildCompactDropdown(
                            value: _collectionFilter,
                            items: {
                              'all': context.t('filter_all'),
                              'favorites': context.t('filter_favorites'),
                              'mine': context.t('filter_my_subjects'),
                              'public': context.t('filter_public'),
                            },
                            onChanged: (val) {
                              if (val != null)
                                setState(() {
                                  _collectionFilter = val;
                                  _applySearch();
                                });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: _buildCompactDropdown(
                            value: _selectedAgeFilter,
                            items: {
                              'all': context.t('age_all'),
                              'early': context.t('age_early'),
                              'primary': context.t('age_primary'),
                              'intermediate': context.t('age_intermediate'),
                            },
                            onChanged: (val) {
                              if (val != null)
                                setState(() {
                                  _selectedAgeFilter = val;
                                  _applySearch();
                                });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            Icons.add_circle,
                            color: currentSessionColor,
                            size: 40,
                          ),
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SubjectEditPage(),
                              ),
                            );
                            if (result == true) _loadDashboard();
                          },
                        ),
                      ],
                    ),
                  ),
          slivers: [
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredSubjects.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _collectionFilter == 'favorites'
                            ? Icons.star_outline
                            : Icons.search_off,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _collectionFilter == 'favorites'
                            ? "Your collection is empty"
                            : "No subjects found",
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.grey,
                        ),
                      ),
                      if (_collectionFilter == 'favorites') ...[
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _collectionFilter = 'public';
                              _applySearch();
                            });
                          },
                          icon: const Icon(Icons.explore),
                          label: const Text("Discover Public Subjects"),
                        ),
                      ],
                    ],
                  ),
                ),
              )
            else if (isSearching)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
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
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 1.4,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final pillar = activePillars[index];
                  // Filter subjects by this pillar from the already-filtered list
                  final pillarSubjects =
                      _filteredSubjects
                          .where((s) => s.pillarId == pillar.id)
                          .toList();

                  return _PillarGridTile(
                    pillar: pillar,
                    count: pillarSubjects.length,
                    onTap:
                        () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => PillarSubjectsPage(
                                  pillar: pillar,
                                  subjects: pillarSubjects,
                                  languageCode: _currentTestingLang,
                                  initialAgeFilter: _selectedAgeFilter,
                                  initialCollectionFilter: _collectionFilter,
                                ),
                          ),
                        ),
                  );
                }, childCount: activePillars.length),
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
  final VoidCallback onTap;

  const _PillarGridTile({
    required this.pillar,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor();
    final pillarIcon = pillar.getIconData();
    final uiLang = TranslationService().currentLocale.languageCode;

    return InkWell(
      onTap: () {
        ThemeService().setSessionColor(pillarColor);
        onTap();
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [pillarColor, pillarColor.withValues(alpha: 0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: pillarColor.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                pillarIcon,
                size: 120,
                color: Colors.white.withValues(alpha: 0.2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(pillarIcon, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pillar.getTranslatedName(uiLang),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    pillar.getTranslatedDescription(uiLang),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  Text(
                    '$count ${context.plural('subject', count)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
  List<SubjectModel> _allSubjects = [];
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
    getIt<CardService>().addListener(_loadData);
  }

  @override
  void dispose() {
    getIt<CardService>().removeListener(_loadData);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final allInPillar = await getIt<CardService>().getSubjectsByPillar(
      widget.pillar.id,
    );
    if (mounted) {
      setState(() {
        _allSubjects = allInPillar;
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final myId = getIt<AuthService>().currentUser?.serverId;

    setState(() {
      _filteredSubjects =
          _allSubjects.where((s) {
            final matchesSearch = s
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

            return matchesSearch && matchesAge && matchesCollection;
          }).toList();

      _filteredSubjects.sort(
        (a, b) => a
            .getName(widget.languageCode)
            .toLowerCase()
            .compareTo(b.getName(widget.languageCode).toLowerCase()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final pillarColor = widget.pillar.getColor();
    return AlioloScrollablePage(
      title: Text(
        widget.pillar.getTranslatedName(widget.languageCode),
        style: const TextStyle(color: Colors.white),
      ),
      appBarColor: pillarColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ],
      fixedBody: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 1,
                child: TextField(
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
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildCompactDropdown(
                  value: _collectionFilter,
                  items: {
                    'all': context.t('filter_all'),
                    'favorites': context.t('filter_favorites'),
                    'mine': context.t('filter_my_subjects'),
                    'public': context.t('filter_public'),
                  },
                  onChanged: (val) {
                    if (val != null)
                      setState(() {
                        _collectionFilter = val;
                        _applyFilters();
                      });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 1,
                child: _buildCompactDropdown(
                  value: _selectedAgeFilter,
                  items: {
                    'all': context.t('age_all'),
                    'early': context.t('age_early'),
                    'primary': context.t('age_primary'),
                    'intermediate': context.t('age_intermediate'),
                  },
                  onChanged: (val) {
                    if (val != null)
                      setState(() {
                        _selectedAgeFilter = val;
                        _applyFilters();
                      });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
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
            ],
          ),
          const SizedBox(height: 40),
        ],
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
