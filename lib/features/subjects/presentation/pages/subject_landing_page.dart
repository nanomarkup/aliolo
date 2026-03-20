import 'package:flutter/material.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/features/testing/presentation/pages/learn_page.dart';
import 'package:aliolo/features/testing/presentation/pages/test_page.dart';
import 'package:aliolo/features/management/presentation/pages/subject_edit_page.dart';
import 'package:aliolo/features/management/presentation/pages/add_card_page.dart';
import 'package:aliolo/features/feedback/presentation/pages/feedback_page.dart';
import 'package:aliolo/core/widgets/aliolo_image.dart';
import 'package:aliolo/core/widgets/counting_grid.dart';
import 'package:aliolo/core/widgets/addition_grid.dart';
import 'package:aliolo/core/widgets/subtraction_grid.dart';
import 'package:aliolo/core/widgets/number_grid.dart';
import 'package:aliolo/core/widgets/multiplication_grid.dart';
import 'package:aliolo/core/widgets/division_grid.dart';

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
  bool _hasUpdated = false;

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

    final cards = await _cardService.getCardsBySubject(_currentSubject.id);
    final updatedSubject = await _cardService.getSubjectById(
      _currentSubject.id,
    );

    if (mounted) {
      setState(() {
        _allCards = cards;
        if (updatedSubject != null) {
          _currentSubject = updatedSubject;
          _hasUpdated = true;
        }
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCards =
          _allCards.where((c) {
            final matchesSearch = c
                .getPrompt(widget.languageCode)
                .toLowerCase()
                .contains(query);
            return matchesSearch;
          }).toList();
    });
  }

  Future<void> _toggleFavorite() async {
    final newState = !_currentSubject.isOnDashboard;
    setState(() => _currentSubject.isOnDashboard = newState);
    try {
      await _cardService.toggleSubjectOnDashboard(_currentSubject.id, newState);
    } catch (e) {
      if (mounted) {
        setState(() => _currentSubject.isOnDashboard = !newState);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating favorite: $e')));
      }
    }
  }

  void _confirmDeleteSubject() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Subject?'),
            content: const Text(
              'This will permanently delete the subject and all its cards.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await _cardService.deleteSubjectById(_currentSubject.id);
                  if (context.mounted) {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, true); // Go back to dashboard
                  }
                },
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
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
    final displayLang = widget.languageCode;

    return ListenableBuilder(
      listenable: _cardService,
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            Navigator.pop(context, _hasUpdated || (result == true));
          },
          child: AlioloScrollablePage(
            title: Text(
              _currentSubject.getName(displayLang),
              style: const TextStyle(
                color: appBarColor,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            appBarColor: pillarColor,
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: appBarColor),
                onPressed: () => Navigator.pop(context, _hasUpdated),
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
              ),
            IconButton(
              icon: const Icon(Icons.feedback, color: appBarColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => FeedbackPage(
                          subjectId: _currentSubject.id,
                          contextTitle: _currentSubject.getName(widget.languageCode),
                          appBarColor: pillarColor,
                        ),
                  ),
                );
              },
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
              const SizedBox(height: 16),
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
                          _currentSubject.getName(displayLang),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_currentSubject
                            .getDescription(displayLang)
                            .isNotEmpty)
                          Text(
                            _currentSubject.getDescription(displayLang),
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
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      context: context,
                      title: context.t('learn_mode_title'),
                      icon: Icons.school,
                      color: pillarColor,
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
                      color: pillarColor,
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
              TextField(
                controller: _searchController,
                onChanged: (_) => _applyFilters(),
                decoration: InputDecoration(
                  hintText: 'Search cards...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
          slivers: [
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredCards.isEmpty)
              const SliverFillRemaining(
                child: Center(child: Text('No cards found')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.only(bottom: 32),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final card = _filteredCards[index];
                    final isCardMine = card.ownerId == _authService.currentUser?.serverId;
                    final answer = card.getAnswer(displayLang);

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
                              child: _buildCardPreview(card, pillarColor, displayLang),
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

  Widget _buildCardPreview(CardModel card, Color pillarColor, String displayLang) {
    if (_currentSubject.isNumbers) {
      return NumberGrid(
        displayChar: card.getNumericalChar(displayLang),
        fontSize: 40,
        color: pillarColor,
      );
    } else if (_currentSubject.isDivision) {
      final parts = card.divisionParts ?? [0, 1];
      return DivisionGrid(
        a: parts[0],
        b: parts[1],
        languageCode: displayLang,
        fontSize: 24,
        color: pillarColor,
      );
    } else if (_currentSubject.isMultiplication) {
      final parts = card.multiplicationParts ?? [1, 0];
      return MultiplicationGrid(
        a: parts[0],
        b: parts[1],
        languageCode: displayLang,
        fontSize: 24,
        color: pillarColor,
      );
    } else if (_currentSubject.isSubtraction) {
      return SubtractionGrid(
        totalSum: card.numericalAnswer,
        maxOperand: _currentSubject.maxOperand,
        iconSize: 18,
      );
    } else if (_currentSubject.isAddition) {
      return AdditionGrid(
        totalSum: card.numericalAnswer,
        maxOperand: _currentSubject.maxOperand,
        iconSize: 18,
      );
    } else if (_currentSubject.isCounting) {
      return CountingGrid(
        count: card.numericalAnswer,
        iconSize: 24,
      );
    } else {
      final imageUrl = card.getImageUrls(displayLang).firstOrNull;
      if (imageUrl != null) {
        return AlioloImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
        );
      }
      return Container(
        color: pillarColor.withAlpha(25),
        child: Icon(
          Icons.image,
          size: 32,
          color: pillarColor,
        ),
      );
    }
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
