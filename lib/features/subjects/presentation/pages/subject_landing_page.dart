import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/features/testing/presentation/pages/test_page.dart';
import 'package:aliolo/features/testing/presentation/pages/learn_page.dart';
import 'package:aliolo/features/management/presentation/pages/subject_edit_page.dart';
import 'package:aliolo/features/management/presentation/pages/add_card_page.dart';

class SubjectLandingPage extends StatefulWidget {
  final SubjectModel subject;
  final List<CardModel> cards;
  final String languageCode;

  const SubjectLandingPage({
    super.key,
    required this.subject,
    required this.cards,
    required this.languageCode,
  });

  @override
  State<SubjectLandingPage> createState() => _SubjectLandingPageState();
}

class _SubjectLandingPageState extends State<SubjectLandingPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _searchController = TextEditingController();

  late SubjectModel _currentSubject;
  List<CardModel> _allCards = [];
  List<CardModel> _filteredCards = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentSubject = widget.subject;
    _allCards = widget.cards;
    _applyFilters();
    _cardService.addListener(_onServiceChange);
  }

  @override
  void dispose() {
    _cardService.removeListener(_onServiceChange);
    _searchController.dispose();
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) {
      _refreshData(silent: true);
    }
  }

  Future<void> _refreshData({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);

    // Fetch latest subject and cards to ensure state is fresh
    final cards = await _cardService.getCardsBySubject(_currentSubject.id);
    final updatedSubject = await _cardService.getSubjectById(
      _currentSubject.id,
    );

    if (mounted) {
      setState(() {
        _allCards = cards;
        if (updatedSubject != null) {
          _currentSubject = updatedSubject;
        }
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final newState = !_currentSubject.isOnDashboard;
    // Update local state immediately for instant UI feedback
    setState(() {
      _currentSubject.isOnDashboard = newState;
    });

    try {
      await _cardService.toggleSubjectOnDashboard(_currentSubject.id, newState);
    } catch (e) {
      if (mounted) {
        // Revert on error
        setState(() {
          _currentSubject.isOnDashboard = !newState;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating favorite: $e')));
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final lang = widget.languageCode.toLowerCase();

    setState(() {
      _filteredCards =
          _allCards.where((c) {
            final answer = c.answers[lang] ?? c.answers['en'] ?? '';
            final prompt = c.prompts[lang] ?? c.prompts['en'] ?? '';
            return answer.toLowerCase().contains(query) ||
                prompt.toLowerCase().contains(query);
          }).toList();
    });
  }

  Future<void> _confirmDeleteSubject() async {
    final cardCount = _allCards.length;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(context.t('delete_subject')),
                content: Text(
                  cardCount > 0
                      ? 'This subject contains $cardCount ${context.plural('card', cardCount)}. Deleting it will permanently remove all of them. Are you sure?'
                      : 'Are you sure you want to delete this empty subject?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.t('cancel')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(context.t('delete')),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirmed) {
      try {
        await _cardService.deleteSubjectById(_currentSubject.id);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.t('subject_deleted'))));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pillar = pillars.firstWhere(
      (p) => p.id == _currentSubject.pillarId,
      orElse: () => pillars.first,
    );
    final pillarColor = pillar.getColor();
    const appBarColor = Colors.white;
    final isOwner =
        _currentSubject.ownerId == _authService.currentUser?.serverId;
    final uiLang = TranslationService().currentLocale.languageCode;

    return ListenableBuilder(
      listenable: _cardService,
      builder: (context, _) {
        return AlioloScrollablePage(
          title: Text(
            _currentSubject.getName(uiLang),
            style: const TextStyle(
              color: appBarColor,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          titleAlignment: Alignment.centerLeft,
          appBarColor: pillarColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: appBarColor),
              onPressed: () => Navigator.pop(context),
            ),
            if (!isOwner)
              IconButton(
                icon: Icon(
                  _currentSubject.isOnDashboard
                      ? Icons.star
                      : Icons.star_border,
                  color: appBarColor,
                ),
                onPressed: _toggleFavorite,
                tooltip: context.t('filter_favorites'),
              ),
            if (isOwner) ...[
              IconButton(
                icon: const Icon(Icons.edit, color: appBarColor),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              SubjectEditPage(existingSubject: _currentSubject),
                    ),
                  );
                  if (result == true) _refreshData();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: appBarColor),
                onPressed: _confirmDeleteSubject,
              ),
            ],
          ],
          fixedBody: Column(
            children: [
              const SizedBox(height: 20),
              // Subject Info Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pillarColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      pillar.getIconData(),
                      size: 40,
                      color: pillarColor,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentSubject.getName(uiLang),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_currentSubject.getDescription(uiLang).isNotEmpty)
                          Text(
                            _currentSubject.getDescription(uiLang),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Action Row: Learn & Test
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      title: context.t('learn_mode_title'),
                      icon: Icons.auto_stories,
                      color: Colors.blue,
                      onTap: () {
                        if (_allCards.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => LearnPage(
                                  card: _allCards.first,
                                  languageCode: widget.languageCode,
                                ),
                          ),
                        ).then((_) => _refreshData(silent: true));
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      title: context.t('test_mode_title'),
                      icon: Icons.quiz,
                      color: Colors.orange,
                      onTap: () {
                        if (_allCards.isEmpty) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => TestPage(
                                  card: _allCards.first,
                                  languageCode: widget.languageCode,
                                ),
                          ),
                        ).then((_) => _refreshData(silent: true));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              // Search & Add Header
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: context.t('search_cards'),
                        prefixIcon: const Icon(Icons.search),
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
                      onChanged: (_) => _applyFilters(),
                    ),
                  ),
                  if (isOwner) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: pillarColor,
                        size: 40,
                      ),
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AddCardPage(
                                  initialSubjectId: _currentSubject.id,
                                  pillarId: _currentSubject.pillarId,
                                ),
                          ),
                        );
                        if (result == true) _refreshData();
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
          slivers: [
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredCards.isEmpty)
              SliverFillRemaining(
                child: Center(child: Text(context.t('no_cards_found'))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.75,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final card = _filteredCards[index];
                    final answer =
                        card.answers[widget.languageCode.toLowerCase()] ??
                        card.answers['en'] ??
                        card.answers.values.firstOrNull ??
                        '';
                    final isCardMine =
                        card.ownerId == _authService.currentUser?.serverId;

                    return InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => AddCardPage(
                                  existingCard: card,
                                  isReadOnly: !isCardMine,
                                ),
                          ),
                        );
                        _refreshData(silent: true);
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 3,
                              child:
                                  card.imageUrl != null
                                      ? Image.network(
                                        card.imageUrl!,
                                        fit: BoxFit.cover,
                                      )
                                      : Container(
                                        color: pillarColor.withValues(
                                          alpha: 0.1,
                                        ),
                                        child: Icon(
                                          Icons.image,
                                          size: 32,
                                          color: pillarColor,
                                        ),
                                      ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                answer,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: _filteredCards.length),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
