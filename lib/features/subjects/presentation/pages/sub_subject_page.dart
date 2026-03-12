import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/learning_language_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/learning/presentation/pages/learning_page.dart';

class SubSubjectPage extends StatefulWidget {
  final SubjectModel subject;
  const SubSubjectPage({super.key, required this.subject});

  @override
  State<SubSubjectPage> createState() => _SubSubjectPageState();
}

class _SubSubjectPageState extends State<SubSubjectPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  List<CardModel> _cards = [];
  bool _isLoading = true;
  String _selectedLanguage = 'EN';

  @override
  void initState() {
    super.initState();
    final userLang = _authService.currentUser?.defaultLanguage;
    _selectedLanguage =
        (userLang == null || userLang.isEmpty) ? 'EN' : userLang;
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final cards = await _cardService.getCardsBySubject(widget.subject.id);
    if (mounted) {
      setState(() {
        _cards = cards;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSessionColor = ThemeService().sessionColorNotifier.value;
    const appBarColor = Colors.white;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        final lang = _selectedLanguage.toLowerCase();
        final filteredCards =
            _cards
                .where(
                  (c) =>
                      c.answers.containsKey(lang) ||
                      c.answers.containsKey('en'),
                )
                .toList();

        return ResizeWrapper(
          child: Scaffold(
            appBar: AppBar(
              title: DragToMoveArea(
                child: SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      Text(
                        widget.subject.name,
                        style: const TextStyle(color: appBarColor),
                      ),
                      const SizedBox(width: 24),
                      Theme(
                        data: Theme.of(
                          context,
                        ).copyWith(canvasColor: currentSessionColor),
                        child: DropdownButton<String>(
                          value: _selectedLanguage.toLowerCase(),
                          underline: const SizedBox(),
                          icon: const Icon(
                            Icons.language,
                            color: appBarColor,
                            size: 22,
                          ),
                          style: const TextStyle(
                            color: appBarColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              setState(
                                () => _selectedLanguage = val.toLowerCase(),
                              );
                              _authService.updateDefaultLanguage(
                                val.toLowerCase(),
                              );
                            }
                          },
                          items:
                              (() {
                                final rawLangs =
                                    LearningLanguageService()
                                        .activeLanguageCodes
                                        .map((l) => l.toLowerCase())
                                        .toSet();
                                if (!rawLangs.contains(
                                  _selectedLanguage.toLowerCase(),
                                )) {
                                  rawLangs.add(_selectedLanguage.toLowerCase());
                                }
                                final list = rawLangs.toList()..sort();
                                return list
                                    .map(
                                      (l) => DropdownMenuItem(
                                        value: l,
                                        child: Text(
                                          LearningLanguageService()
                                              .getLanguageName(l),
                                        ),
                                      ),
                                    )
                                    .toList();
                              })(),
                        ),
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
                  onPressed:
                      () => Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SubjectPage(),
                        ),
                        (route) => false,
                      ),
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
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilePage(),
                        ),
                      ),
                ),
                const WindowControls(color: appBarColor, iconSize: 24),
              ],
            ),
            body:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredCards.isEmpty
                    ? Center(child: Text(context.t('no_cards_available_lang')))
                    : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredCards.length,
                      itemBuilder: (context, index) {
                        final card = filteredCards[index];
                        final pillar = pillars.firstWhere(
                          (p) => p.id == widget.subject.pillarId,
                          orElse: () => pillars.first,
                        );
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading:
                                card.imageUrl != null
                                    ? Image.network(
                                      card.imageUrl!,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                    : Icon(
                                      Icons.image,
                                      color: pillar.getColor(),
                                    ),
                            title: Text(
                              card.prompts[lang] ??
                                  card.prompts['en'] ??
                                  card.prompts.values.firstOrNull ??
                                  'No Prompt',
                            ),
                            subtitle: Text(
                              '${context.t('level')} ${card.level}',
                            ),
                            trailing: const Icon(Icons.play_arrow),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => LearningPage(
                                        card: card,
                                        languageCode: _selectedLanguage,
                                      ),
                                ),
                              );
                              _loadCards();
                            },
                          ),
                        );
                      },
                    ),
          ),
        );
      },
    );
  }
}
