import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
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

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final _cardService = getIt<CardService>();
  
  List<SubjectModel> _dashboardSubjects = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    _loadDashboard();
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
    const currentSessionColor = ThemeService.mainColor;

    final activePillarIds = _dashboardSubjects.map((s) => s.pillarId).toSet();
    final activePillars = pillars.where((p) => activePillarIds.contains(p.id)).toList();

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        final lang = TranslationService().currentLocale.languageCode.toLowerCase();
        return ResizeWrapper(
          child: Scaffold(
            appBar: AppBar(
              title: DragToMoveArea(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(context.t('learn'), style: const TextStyle(color: appBarColor)),
                ),
              ),
              backgroundColor: currentSessionColor,
              foregroundColor: appBarColor,
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.school, color: appBarColor),
                  onPressed: () => _loadDashboard(),
                ),
                IconButton(
                  icon: const Icon(Icons.style, color: appBarColor),
                  tooltip: context.t('manage_library'),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCardsPage()));
                    _loadDashboard();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.emoji_events, color: appBarColor),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())),
                ),
                IconButton(
                  icon: const Icon(Icons.person, color: appBarColor),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
                    _loadDashboard();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.settings, color: appBarColor),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
                ),
                const WindowControls(color: appBarColor, iconSize: 24),
              ],
            ),
            body: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: activePillars.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.dashboard_customize, size: 80, color: Colors.grey),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(context.t('empty_dashboard'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, color: Colors.grey)),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCardsPage()));
                            _loadDashboard();
                          },
                          icon: const Icon(Icons.style),
                          label: Text(context.t('manage_library')),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(32),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: activePillars.length,
                    itemBuilder: (context, index) {
                      final pillar = activePillars[index];
                      final count = _dashboardSubjects.where((s) => s.pillarId == pillar.id).length;
                      final pillarColor = pillar.getColor();
                      final pillarIcon = pillar.getIconData();
                      
                      return InkWell(
                        onTap: () {
                          ThemeService().setSessionColor(pillarColor);
                          final pillarSubjects = _dashboardSubjects.where((s) => s.pillarId == pillar.id).toList();
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => PillarSubjectsPage(pillar: pillar, subjects: pillarSubjects)),
                          );
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
                              BoxShadow(color: pillarColor.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
                            ],
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -20, bottom: -20,
                                child: Icon(pillarIcon, size: 120, color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(pillarIcon, color: Colors.white, size: 40),
                                    const Spacer(),
                                    Text(
                                      pillar.translations[lang] ?? pillar.translations['en'] ?? pillar.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '$count ${context.t('subjects')}',
                                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ),
        );
      },
    );
  }
}

class PillarSubjectsPage extends StatefulWidget {
  final Pillar pillar;
  final List<SubjectModel> subjects;

  const PillarSubjectsPage({super.key, required this.pillar, required this.subjects});

  @override
  State<PillarSubjectsPage> createState() => _PillarSubjectsPageState();
}

class _PillarSubjectsPageState extends State<PillarSubjectsPage> {
  late String _currentLearningLang;
  bool _isInitializedFromUser = false;

  @override
  void initState() {
    super.initState();
    final user = getIt<AuthService>().currentUser;
    _currentLearningLang = (user?.defaultLanguage ?? 'en').toLowerCase();
    _isInitializedFromUser = user != null;
    
    // Listen for profile changes to sync initial language
    getIt<AuthService>().addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    getIt<AuthService>().removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted && !_isInitializedFromUser) {
      final user = getIt<AuthService>().currentUser;
      if (user != null) {
        setState(() {
          _currentLearningLang = user.defaultLanguage.toLowerCase();
          _isInitializedFromUser = true;
        });
      }
    }
  }

  void _updateLanguage(String newLang) {
    setState(() => _currentLearningLang = newLang);
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    const currentSessionColor = ThemeService.mainColor;
    final lang = TranslationService().currentLocale.languageCode.toLowerCase();
    final activeLangs = getIt<LearningLanguageService>().activeLanguageCodes;
    
    return ResizeWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: DragToMoveArea(
            child: SizedBox(
              width: double.infinity,
              child: Row(
                children: [
                  Text(
                    '${widget.pillar.translations[lang] ?? widget.pillar.translations['en'] ?? widget.pillar.name} • ', 
                    style: const TextStyle(color: appBarColor)
                  ),
                  DropdownButton<String>(
                    value: _currentLearningLang.toLowerCase(),
                    dropdownColor: currentSessionColor,
                    style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold, fontSize: 18),
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: appBarColor),
                    items: activeLangs.map((l) => DropdownMenuItem(
                      value: l.toLowerCase(), 
                      child: Text(getIt<LearningLanguageService>().getLanguageName(l))
                    )).toList(),
                    onChanged: (val) {
                      if (val != null) _updateLanguage(val.toLowerCase());
                    },
                  ),
                ],
              ),
            ),
          ),
          backgroundColor: currentSessionColor,
          foregroundColor: appBarColor,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.school, color: appBarColor),
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SubjectPage()), (route) => false),
            ),
            IconButton(
              icon: const Icon(Icons.style, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCardsPage())),
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())),
            ),
            IconButton(
              icon: const Icon(Icons.person, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
            ),
            const WindowControls(color: appBarColor, iconSize: 24),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: widget.subjects.map((subject) {
                  final pillarColor = widget.pillar.getColor();
                  final cardCount = subject.getCardCountForLanguage(_currentLearningLang);
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: InkWell(
                      onTap: () async {
                        final cards = await CardService().getCardsBySubject(subject.id);
                        if (cards.isNotEmpty && context.mounted) {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => LearningPage(card: cards.first, languageCode: _currentLearningLang)));
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('no_cards_found'))));
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: pillarColor.withValues(alpha: 0.2), width: 1.5),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subject.name, 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                                  ),
                                  if (subject.description != null && subject.description!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      subject.description!,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
