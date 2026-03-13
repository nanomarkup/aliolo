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
import 'package:aliolo/data/services/learning_language_service.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/management/presentation/pages/manage_cards_page.dart';
import 'package:aliolo/features/learning/presentation/pages/learning_page.dart';

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final _cardService = getIt<CardService>();
  final _searchController = TextEditingController();
  late String _currentLearningLang = 'en';
  bool _isLangInitialized = false;

  List<SubjectModel> _allDashboardSubjects = [];
  List<SubjectModel> _filteredSubjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    ThemeService().setSessionColor(ThemeService().primaryColor);
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    _initLanguage();
    _loadDashboard();
  }

  void _initLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('last_learning_lang');

    if (mounted) {
      if (savedLang != null) {
        setState(() {
          _currentLearningLang = savedLang;
          _isLangInitialized = true;
        });
      } else {
        final user = getIt<AuthService>().currentUser;
        if (user != null) {
          setState(() {
            _currentLearningLang = user.defaultLanguage.toLowerCase();
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
    _searchController.dispose();
    super.dispose();
  }

  void _onAuthChanged() async {
    if (mounted && !_isLangInitialized) {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('last_learning_lang');
      if (savedLang != null) {
        setState(() {
          _currentLearningLang = savedLang;
          _isLangInitialized = true;
        });
        return;
      }

      final user = getIt<AuthService>().currentUser;
      if (user != null) {
        setState(() {
          _currentLearningLang = user.defaultLanguage.toLowerCase();
          _isLangInitialized = true;
        });
      }
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    // Fetch pillars from DB
    await _cardService.getPillars();
    final subjects = await _cardService.getDashboardSubjects();
    
    if (mounted) {
      // If still no pillars (e.g. offline), we might want to show an error or empty state
      if (pillars.isEmpty) {
        setState(() {
          _allDashboardSubjects = [];
          _isLoading = false;
        });
        return;
      }

      // Extract all unique languages from cards
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
        getIt<LearningLanguageService>().addActiveLanguages(
          detectedLangs.toList(),
        );
      }

      setState(() {
        _allDashboardSubjects = subjects;
        _applySearch();
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSubjects =
          _allDashboardSubjects.where((s) {
            final matchesName = s
                .getName(_currentLearningLang)
                .toLowerCase()
                .contains(query);
            final hasCards =
                s.getCardCountForLanguage(_currentLearningLang) > 0;
            return matchesName && hasCards;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    final currentSessionColor = ThemeService().sessionColorNotifier.value;
    final rawActiveLangs =
        getIt<LearningLanguageService>()
            .activeLanguageCodes
            .map((l) => l.toLowerCase())
            .toSet();
    final List<String> activeLangs = rawActiveLangs.toList()..sort();
    if (!activeLangs.contains(_currentLearningLang.toLowerCase())) {
      activeLangs.add(_currentLearningLang.toLowerCase());
      activeLangs.sort();
    }

    final isSearching = _searchController.text.isNotEmpty;
    final activePillarIds = _filteredSubjects.map((s) => s.pillarId).toSet();
    final activePillars = pillars
        .where((p) => activePillarIds.contains(p.id))
        .toList();

    return ListenableBuilder(
      listenable: Listenable.merge([
        TranslationService(),
        getIt<LearningLanguageService>(),
      ]),
      builder: (context, _) {
        return AlioloScrollablePage(
          title: DropdownButton<String>(
            value: _currentLearningLang.toLowerCase(),
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
                          getIt<LearningLanguageService>().getLanguageName(l),
                        ),
                      ),
                    )
                    .toList(),
            onChanged: (val) async {
              if (val != null) {
                setState(() => _currentLearningLang = val.toLowerCase());
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('last_learning_lang', val.toLowerCase());
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
              icon: const Icon(Icons.collections_bookmark, color: appBarColor),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ManageCardsPage(),
                  ),
                );
                _loadDashboard();
              },
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
          slivers: [
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_allDashboardSubjects.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageCardsPage(),
                            ),
                          );
                          _loadDashboard();
                        },
                        borderRadius: BorderRadius.circular(40),
                        child: const Icon(
                          Icons.dashboard_customize,
                          size: 120,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageCardsPage(),
                            ),
                          );
                          _loadDashboard();
                        },
                        child: Text(context.t('manage_subjects')),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.t('search_subjects'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon:
                          _searchController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _applySearch();
                                },
                              )
                              : null,
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
                ),
              ),
              if (isSearching)
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final subject = _filteredSubjects[index];
                    final pillar = pillars.firstWhere(
                      (p) => p.id == subject.pillarId,
                    );
                    final pillarColor = pillar.getColor();
                    final cardCount = subject.getCardCountForLanguage(
                      _currentLearningLang,
                    );

                    final isMine =
                        subject.ownerId == getIt<AuthService>().currentUser?.serverId;
                    final authorLabel =
                        isMine ? context.t('you') : (subject.ownerName ?? '...');
                    final privacyLabel =
                        (isMine && !subject.isPublic)
                            ? ' • 🔒 ${context.t('private')}'
                            : '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: InkWell(
                        onTap: () async {
                          final cards = await CardService().getCardsBySubject(
                            subject.id,
                          );
                          if (cards.isNotEmpty && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => LearningPage(
                                      card: cards.first,
                                      languageCode: _currentLearningLang,
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
                                      subject.getName(_currentLearningLang),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      '${pillar.getTranslatedName(_currentLearningLang)} • $cardCount ${context.plural('card', cardCount)} • $authorLabel$privacyLabel',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }, childCount: _filteredSubjects.length),
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
                    final pillarSubjects =
                        _allDashboardSubjects
                            .where((s) => s.pillarId == pillar.id)
                            .toList();
                    final count =
                        pillarSubjects
                            .where(
                              (s) =>
                                  s.getCardCountForLanguage(
                                    _currentLearningLang,
                                  ) >
                                  0,
                            )
                            .length;
                    final pillarColor = pillar.getColor();
                    final pillarIcon = pillar.getIconData();

                    return InkWell(
                      onTap: () {
                        ThemeService().setSessionColor(pillarColor);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => PillarSubjectsPage(
                                  pillar: pillar,
                                  subjects: pillarSubjects,
                                  languageCode: _currentLearningLang,
                                ),
                          ),
                        ).then((_) {
                          ThemeService().setSessionColor(ThemeService().primaryColor);
                        });
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              pillarColor,
                              pillarColor.withValues(alpha: 0.7),
                            ],
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        pillarIcon,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          pillar.getTranslatedName(
                                            _currentLearningLang,
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            height: 1.0,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    pillar.getTranslatedDescription(
                                      _currentLearningLang,
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      height: 1.3,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$count ${context.plural('subject', count)}',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.8,
                                      ),
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
                  }, childCount: activePillars.length),
                ),
            ],
          ],
        );
      },
    );
  }
}

class PillarSubjectsPage extends StatefulWidget {
  final Pillar pillar;
  final List<SubjectModel> subjects;
  final String languageCode;

  const PillarSubjectsPage({
    super.key,
    required this.pillar,
    required this.subjects,
    required this.languageCode,
  });

  @override
  State<PillarSubjectsPage> createState() => _PillarSubjectsPageState();
}

class _PillarSubjectsPageState extends State<PillarSubjectsPage> {
  final _searchController = TextEditingController();
  List<SubjectModel> _filteredSubjects = [];

  @override
  void initState() {
    super.initState();
    _applySearch();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applySearch() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSubjects =
          widget.subjects.where((s) {
            final matchesName = s
                .getName(widget.languageCode)
                .toLowerCase()
                .contains(query);
            final hasCards = s.getCardCountForLanguage(widget.languageCode) > 0;
            return matchesName && hasCards;
          }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    final pillarColor = widget.pillar.getColor();

    return AlioloScrollablePage(
      title: Text(
        widget.pillar.getTranslatedName(widget.languageCode),
        style: const TextStyle(color: appBarColor),
      ),
      appBarColor: pillarColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: context.t('search_subjects'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _searchController.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applySearch();
                          },
                        )
                        : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
              ),
              onChanged: (_) => _applySearch(),
            ),
          ),
        ),
        if (_filteredSubjects.isEmpty)
          SliverFillRemaining(
            child: Center(child: Text('No ${context.plural('subject', 0)} found')),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final subject = _filteredSubjects[index];
                final cardCount = subject.getCardCountForLanguage(
                  widget.languageCode,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () async {
                      final cards = await CardService().getCardsBySubject(
                        subject.id,
                      );
                      if (cards.isNotEmpty && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => LearningPage(
                                  card: cards.first,
                                  languageCode: widget.languageCode,
                                ),
                          ),
                        );
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.t('no_cards_found'))),
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject.getName(widget.languageCode),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                                (() {
                                  final isMine =
                                      subject.ownerId ==
                                      getIt<AuthService>()
                                          .currentUser
                                          ?.serverId;
                                  final label =
                                      isMine
                                          ? context.t('you')
                                          : (subject.ownerName ?? '...');
                                  final isPrivate = isMine && !subject.isPublic;

                                  return Row(
                                    children: [
                                      Text(
                                        '${context.t('author')}: $label',
                                        style: TextStyle(
                                          color: pillarColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (isPrivate) ...[
                                        const SizedBox(width: 8),
                                        const Icon(
                                          Icons.lock,
                                          size: 12,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          context.t('private'),
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                })(),
                                if (subject
                                    .getDescription(widget.languageCode)
                                    .isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    subject.getDescription(widget.languageCode),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: pillarColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$cardCount ${context.plural('card', cardCount)}',
                              style: TextStyle(
                                color: pillarColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }, childCount: _filteredSubjects.length),
            ),
          ),
      ],
    );
  }
}
