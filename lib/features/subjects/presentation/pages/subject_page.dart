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
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/management/presentation/pages/manage_cards_page.dart';
import 'package:aliolo/features/learning/presentation/pages/learning_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/sub_subject_page.dart';

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final _cardService = getIt<CardService>();
  late String _currentLearningLang = 'en';
  bool _isLangInitialized = false;

  List<SubjectModel> _dashboardSubjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    ThemeService().setSessionColor(ThemeService.mainColor);
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
    final subjects = await _cardService.getDashboardSubjects();
    if (mounted) {
      setState(() {
        _dashboardSubjects = subjects;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    final currentSessionColor = ThemeService().sessionColorNotifier.value;
    final rawActiveLangs =
        getIt<LearningLanguageService>().activeLanguageCodes
            .map((l) => l.toLowerCase())
            .toSet();
    final List<String> activeLangs = rawActiveLangs.toList()..sort();
    if (!activeLangs.contains(_currentLearningLang.toLowerCase())) {
      activeLangs.add(_currentLearningLang.toLowerCase());
      activeLangs.sort();
    }

    final activePillarIds = _dashboardSubjects.map((s) => s.pillarId).toSet();
    final activePillars =
        pillars.where((p) => activePillarIds.contains(p.id)).toList();

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
            else if (activePillars.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.dashboard_customize,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          context.t('empty_dashboard'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ManageCardsPage(),
                            ),
                          );
                          _loadDashboard();
                        },
                        icon: const Icon(Icons.collections_bookmark),
                        label: Text(context.t('manage_subjects')),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 24,
                  childAspectRatio: 1.5,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final pillar = activePillars[index];
                  final pillarSubjects =
                      _dashboardSubjects
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
                      );
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
                                Icon(pillarIcon, color: Colors.white, size: 40),
                                const Spacer(),
                                FutureBuilder<String>(
                                  future: TranslationService()
                                      .translateForLanguage(
                                        'pillar_${pillar.name}',
                                        _currentLearningLang,
                                      ),
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data ??
                                          pillar.getTranslatedName(
                                            _currentLearningLang,
                                          ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
                                ),
                                Text(
                                  '$count ${context.t('subjects')}',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 14,
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
  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    final pillarColor = widget.pillar.getColor();

    final filteredSubjects =
        widget.subjects
            .where((s) => s.getCardCountForLanguage(widget.languageCode) > 0)
            .toList();

    return AlioloScrollablePage(
      title: FutureBuilder<String>(
        future: TranslationService().translateForLanguage(
          'pillar_${widget.pillar.name}',
          widget.languageCode,
        ),
        builder: (context, snapshot) {
          return Text(
            snapshot.data ??
                widget.pillar.getTranslatedName(widget.languageCode),
            style: const TextStyle(color: appBarColor),
          );
        },
      ),
      appBarColor: pillarColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
      ],
      slivers: [
        if (filteredSubjects.isEmpty)
          SliverFillRemaining(
            child: Center(child: Text(context.t('no_subjects_found'))),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final subject = filteredSubjects[index];
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
                                FutureBuilder<String>(
                                  future: TranslationService()
                                      .translateForLanguage(
                                        subject.name,
                                        widget.languageCode,
                                      ),
                                  builder: (context, snapshot) {
                                    return Text(
                                      snapshot.data ?? subject.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    );
                                  },
                                ),
                                if (subject.description != null &&
                                    subject.description!.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  FutureBuilder<String>(
                                    future: TranslationService()
                                        .translateForLanguage(
                                          subject.description!,
                                          widget.languageCode,
                                        ),
                                    builder: (context, snapshot) {
                                      return Text(
                                        snapshot.data ?? subject.description!,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      );
                                    },
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
                              '$cardCount ${context.t('cards_label')}',
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
              }, childCount: filteredSubjects.length),
            ),
          ),
      ],
    );
  }
}
