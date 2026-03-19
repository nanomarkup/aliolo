import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/features/management/presentation/pages/add_card_page.dart';
import 'package:aliolo/features/management/presentation/pages/subject_edit_page.dart';

class SubjectDetailsPage extends StatefulWidget {
  final SubjectModel subject;
  const SubjectDetailsPage({super.key, required this.subject});

  @override
  State<SubjectDetailsPage> createState() => _SubjectDetailsPageState();
}

class _SubjectDetailsPageState extends State<SubjectDetailsPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _searchController = TextEditingController();

  late SubjectModel _currentSubject;
  List<CardModel> _allCards = [];
  List<CardModel> _filteredCards = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentSubject = widget.subject;
    _loadCards();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final cards = await _cardService.getCardsBySubject(_currentSubject.id);
    if (mounted) {
      setState(() {
        _allCards = cards;
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final lang =
        _authService.currentUser?.defaultLanguage.toLowerCase() ?? 'en';

    setState(() {
      _filteredCards =
          _allCards.where((c) {
            final answer = c.getAnswer(lang);
            final prompt = c.getPrompt(lang);
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
    final currentSessionColor = pillar.getColor();
    const appBarColor = Colors.white;
    final lang =
        _authService.currentUser?.defaultLanguage.toLowerCase() ?? 'en';
    final uiLang = TranslationService().currentLocale.languageCode;
    final isMine =
        _currentSubject.ownerId == _authService.currentUser?.serverId;

    return AlioloScrollablePage(
      title: Text(
        _currentSubject.getName(uiLang),
        style: const TextStyle(color: appBarColor),
      ),
      appBarColor: currentSessionColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
        if (isMine) ...[
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
              if (result == true) {
                final updated = await _cardService.getSubjectById(
                  _currentSubject.id,
                );
                if (updated != null && mounted) {
                  setState(() => _currentSubject = updated);
                }
              }
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
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: context.t('search_cards'),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) {
                        return value.text.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                            : const SizedBox.shrink();
                      },
                    ),
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
              if (isMine) ...[
                const SizedBox(width: 12),
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
                        builder:
                            (context) => AddCardPage(
                              initialSubjectId: _currentSubject.id,
                              pillarId: _currentSubject.pillarId,
                            ),
                      ),
                    );
                    if (result == true) _loadCards();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
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
                childAspectRatio: 0.7,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final card = _filteredCards[index];
                final answer = card.getAnswer(lang);
                final isCardMine =
                    card.ownerId == _authService.currentUser?.serverId;
                final imageUrl = card.primaryImageUrl;

                return InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => AddCardPage(
                              existingCard: card,
                              isReadOnly: !isCardMine,
                              pillarId: _currentSubject.pillarId,
                            ),
                      ),
                    );                    _loadCards();
                  },
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child:
                              imageUrl != null
                                  ? Image.network(imageUrl, fit: BoxFit.cover)
                                  : Container(
                                    color: pillar.getColor().withValues(
                                      alpha: 0.1,
                                    ),
                                    child: Icon(
                                      Icons.image,
                                      size: 48,
                                      color: pillar.getColor(),
                                    ),
                                  ),
                        ),
                        Expanded(
                          flex: 1,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            color: Theme.of(context).cardColor,
                            child: Center(
                              child: Text(
                                answer,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
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
  }
}
