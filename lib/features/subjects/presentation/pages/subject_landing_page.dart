import 'package:flutter/material.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/folder_model.dart';
import 'package:aliolo/data/models/collection_model.dart';
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
  final SubjectModel? subject;
  final FolderModel? folder;
  final CollectionModel? collection;
  final List<CardModel> cards;
  final String languageCode;

  const SubjectLandingPage({
    super.key,
    this.subject,
    this.folder,
    this.collection,
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

  SubjectModel? _currentSubject;
  FolderModel? _currentFolder;
  CollectionModel? _currentCollection;
  List<CardModel> _allCards = [];
  List<CardModel> _filteredCards = [];
  List<SubjectModel> _allSubjects = [];
  List<SubjectModel> _filteredSubjects = [];
  bool _isLoading = false;
  bool _hasUpdated = false;

  String _collectionFilter = 'all';
  String _selectedAgeFilter = 'all';

  @override
  void initState() {
    super.initState();
    _currentSubject = widget.subject;
    _currentFolder = widget.folder;
    _currentCollection = widget.collection;
    _allCards = widget.cards;
    
    if (_currentCollection != null) {
      _fetchCollectionSubjects();
    } else {
      _applyFilters();
    }
    _cardService.addListener(_onServiceChange);
  }

  Future<void> _fetchCollectionSubjects() async {
    if (_currentCollection == null) return;
    setState(() => _isLoading = true);
    try {
      final subjects = await _cardService.getDashboardSubjects();
      if (mounted) {
        setState(() {
          _allSubjects = subjects;
          _applyFilters();
        });
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    if (_currentSubject == null) return;
    if (!silent) setState(() => _isLoading = true);

    final cards = await _cardService.getCardsBySubject(_currentSubject!.id);
    final updatedSubject = await _cardService.getSubjectById(
      _currentSubject!.id,
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
    final myId = _authService.currentUser?.serverId;
    
    setState(() {
      if (_currentCollection != null) {
        _filteredSubjects = _allSubjects.where((s) {
          final matchesName = s.getName(widget.languageCode).toLowerCase().contains(query);
          final matchesAge = _selectedAgeFilter == 'all' || s.ageGroup == _selectedAgeFilter;
          bool matchesCollection = true;
          if (_collectionFilter == 'mine') {
            matchesCollection = s.ownerId == myId;
          } else if (_collectionFilter == 'public') {
            matchesCollection = s.isPublic;
          } else if (_collectionFilter == 'favorites') {
            matchesCollection = s.isOnDashboard;
          }
          return matchesName && matchesAge && matchesCollection;
        }).toList();

        _filteredSubjects.sort((a, b) {
          final aSelected = _currentCollection!.subjectIds.contains(a.id);
          final bSelected = _currentCollection!.subjectIds.contains(b.id);
          if (aSelected && !bSelected) return -1;
          if (!aSelected && bSelected) return 1;
          return a.getName(widget.languageCode).toLowerCase().compareTo(b.getName(widget.languageCode).toLowerCase());
        });
      } else {
        _filteredCards = _allCards.where((c) {
          final matchesSearch = c
              .getPrompt(widget.languageCode)
              .toLowerCase()
              .contains(query);
          return matchesSearch;
        }).toList();
      }
    });
  }

  Future<void> _toggleFavorite() async {
    if (_currentSubject == null) return;
    final newState = !_currentSubject!.isOnDashboard;
    setState(() => _currentSubject!.isOnDashboard = newState);
    try {
      await _cardService.toggleSubjectOnDashboard(_currentSubject!.id, newState);
    } catch (e) {
      if (mounted) {
        setState(() => _currentSubject!.isOnDashboard = !newState);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating favorite: $e')));
      }
    }
  }

  void _confirmDeleteSubject() {
    if (_currentSubject == null && _currentCollection == null) return;
    final isCollection = _currentCollection != null;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(isCollection ? context.t('delete_collection') : context.t('delete_subject')),
            content: Text(
              isCollection 
                  ? context.t('delete_collection_confirm')
                  : 'This will permanently delete the subject and all its cards.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('cancel')),
              ),
              TextButton(
                onPressed: () async {
                  if (isCollection) {
                    await _cardService.deleteCollection(_currentCollection!.id);
                  } else {
                    await _cardService.deleteSubjectById(_currentSubject!.id);
                  }
                  if (context.mounted) {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, true); // Go back to dashboard
                  }
                },
                child: Text(context.t('delete'), style: const TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );
  }

  Future<void> _startSession(bool isTest) async {
    List<SubjectCard> sessionCards = [];
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      if (_currentCollection != null) {
        sessionCards = await _cardService.getCollectionCards(
          _currentCollection!.subjectIds,
        );
      } else if (_currentSubject?.type == 'collection') {
        sessionCards = await _cardService.getCollectionCards(
          _currentSubject!.linkedSubjectIds,
        );
      } else if (_currentFolder != null) {
        final subSubjects = await _cardService.getSubjectsByPillar(
          _currentFolder!.pillarId,
          folderId: _currentFolder!.id,
        );
        for (var s in subSubjects) {
          final cards = await _cardService.getCardsBySubject(s.id);
          sessionCards.addAll(
            cards.map((c) => SubjectCard(card: c, subject: s)),
          );
        }
      } else if (_currentSubject != null) {
        // standard
        sessionCards =
            _allCards
                .map((c) => SubjectCard(card: c, subject: _currentSubject!))
                .toList();
      }

      // Filter and Shuffle logic
      final lang = widget.languageCode.toLowerCase();
      sessionCards =
          sessionCards.where((sc) {
            return sc.card.getAnswer(lang).isNotEmpty ||
                sc.card.getAnswer('en').isNotEmpty;
          }).toList();

      sessionCards.shuffle();
      final size = isTest ? user.testSessionSize : user.learnSessionSize;
      sessionCards = sessionCards.take(size).toList();

      if (sessionCards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No cards available for this session.'),
            ),
          );
        }
        return;
      }

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    isTest
                        ? TestPage(
                          sessionCards: sessionCards,
                          languageCode: widget.languageCode,
                        )
                        : LearnPage(
                          sessionCards: sessionCards,
                          languageCode: widget.languageCode,
                        ),
          ),
        );
        if (_currentSubject != null) _refreshData(silent: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildCompactDropdown({required String value, required Map<String, String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withValues(alpha: 0.5))),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, isExpanded: true, icon: const Icon(Icons.arrow_drop_down, size: 20),
        style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pillarId = _currentSubject?.pillarId ?? _currentFolder?.pillarId ?? _currentCollection?.pillarId ?? 1;
    final pillar = pillars.firstWhere(
      (p) => p.id == pillarId,
      orElse: () => pillars.first,
    );
    final pillarColor = pillar.getColor();
    const appBarColor = Colors.white;
    final isOwner = (_currentSubject != null && _currentSubject!.ownerId == _authService.currentUser?.serverId) ||
                  (_currentCollection != null && _currentCollection!.ownerId == _authService.currentUser?.serverId);
    final displayLang = widget.languageCode;
    final title = _currentSubject?.getName(displayLang) ?? 
                 _currentFolder?.getName(displayLang) ?? 
                 _currentCollection?.getName(displayLang) ?? 
                 'Aliolo';

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
              title,
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
            if (!isOwner && _currentSubject != null)
              IconButton(
                icon: Icon(
                  _currentSubject!.isOnDashboard
                      ? Icons.star
                      : Icons.star_border,
                  color: appBarColor,
                ),
                onPressed: _toggleFavorite,
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
                              SubjectEditPage(
                                existingSubject: _currentSubject ?? SubjectModel(
                                  id: _currentCollection!.id,
                                  pillarId: _currentCollection!.pillarId,
                                  ownerId: _currentCollection!.ownerId,
                                  isPublic: _currentCollection!.isPublic,
                                  createdAt: _currentCollection!.createdAt,
                                  updatedAt: _currentCollection!.updatedAt,
                                  localizedData: _currentCollection!.localizedData,
                                  folderId: _currentCollection!.folderId,
                                  type: 'collection',
                                  linkedSubjectIds: _currentCollection!.subjectIds,
                                ),
                                isCollectionMode: _currentCollection != null,
                              ),
                    ),
                  );
                  if (result == true) {
                    if (_currentSubject != null) _refreshData();
                    // Just pop if collection updated so dashboard refreshes it
                    if (_currentCollection != null) {
                      if (context.mounted) Navigator.pop(context, true);
                    }
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: appBarColor),
                onPressed: _confirmDeleteSubject,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.feedback, color: appBarColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => FeedbackPage(
                          subjectId: _currentSubject?.id,
                          folderId: _currentFolder?.id,
                          collectionId: _currentCollection?.id,
                          contextTitle: title,
                          appBarColor: pillarColor,
                        ),
                  ),
                );
              },
            ),
          ],
          fixedBody: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              final filterRow = _currentCollection != null ? Row(children: [
                Expanded(child: _buildCompactDropdown(value: _collectionFilter, items: {'all': context.t('filter_all'), 'favorites': context.t('filter_favorites'), 'mine': context.t('filter_my_subjects'), 'public': context.t('filter_public')}, onChanged: (val) { if (val != null) setState(() { _collectionFilter = val; _applyFilters(); }); })),
                const SizedBox(width: 8),
                Expanded(child: _buildCompactDropdown(value: _selectedAgeFilter, items: {'all': context.t('age_all'), '0_6': context.t('age_0_6'), '7_14': context.t('age_7_14'), '15_plus': context.t('age_15_plus')}, onChanged: (val) { if (val != null) setState(() { _selectedAgeFilter = val; _applyFilters(); }); })),
              ]) : const SizedBox.shrink();

              return Column(
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
                          _currentFolder != null ? Icons.folder : 
                          (_currentCollection != null ? Icons.collections : pillar.getIconData()),
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
                              title,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_currentSubject?.getDescription(displayLang).isNotEmpty == true || 
                                _currentFolder?.getDescription(displayLang).isNotEmpty == true ||
                                _currentCollection?.getDescription(displayLang).isNotEmpty == true)
                              Text(
                                _currentSubject?.getDescription(displayLang) ?? 
                                _currentFolder?.getDescription(displayLang) ?? 
                                _currentCollection?.getDescription(displayLang) ?? '',
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
                          onTap: () => _startSession(false),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          context: context,
                          title: context.t('test_mode_title'),
                          icon: Icons.quiz,
                          color: pillarColor,
                          onTap: () => _startSession(true),
                        ),
                      ),
                    ],
                  ),
                  if (_currentSubject != null || _currentCollection != null) ...[
                    const SizedBox(height: 32),
                    if (_currentCollection != null && isSmall) ...[
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => _applyFilters(),
                        decoration: InputDecoration(
                          hintText: context.t('search_subjects'),
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
                        ),
                      ),
                      const SizedBox(height: 12),
                      filterRow,
                    ] else if (_currentCollection != null && !isSmall) ...[
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => _applyFilters(),
                              decoration: InputDecoration(
                                hintText: context.t('search_subjects'),
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
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(flex: 5, child: filterRow),
                        ],
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              onChanged: (_) => _applyFilters(),
                              decoration: InputDecoration(
                                hintText: 'Search cards...',
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
                              ),
                            ),
                          ),
                          if (isOwner && _currentSubject != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
                              padding: EdgeInsets.zero,
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddCardPage(
                                      pillarId: pillarId,
                                      initialSubjectId: _currentSubject!.id,
                                    ),
                                  ),
                                );
                                if (result == true) _refreshData();
                              },
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],
              );
            },
          ),
          slivers: [
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_currentSubject == null && _currentCollection == null)
              const SliverFillRemaining(
                child: Center(child: Text('This is a folder. You can use Learn/Test buttons above to practice all cards.')),
              )
            else if (_currentCollection != null)
              if (_filteredSubjects.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No subjects found in this collection')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.only(bottom: 32),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final subject = _filteredSubjects[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () async {
                            final cards = await _cardService.getCardsBySubject(subject.id);
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SubjectLandingPage(
                                    subject: subject,
                                    cards: cards,
                                    languageCode: displayLang,
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
                              border: Border.all(color: pillarColor.withValues(alpha: 0.2), width: 1.5),
                            ),
                            child: Row(
                              children: [
                                if (isOwner)
                                  Checkbox(
                                    value: _currentCollection!.subjectIds.contains(subject.id),
                                    activeColor: pillarColor,
                                    onChanged: (val) async {
                                      if (val == null) return;
                                      setState(() {
                                        if (val) {
                                          _currentCollection!.subjectIds.add(subject.id);
                                        } else {
                                          _currentCollection!.subjectIds.remove(subject.id);
                                        }
                                        _hasUpdated = true;
                                      });
                                      await _cardService.addCollection(_currentCollection!, _currentCollection!.subjectIds);
                                    },
                                  )
                                else
                                  Icon(Icons.description, color: pillarColor),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        subject.getName(displayLang),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                      ),
                                      Text(
                                        '${pillars.firstWhere((p) => p.id == subject.pillarId, orElse: () => pillars.first).getTranslatedName(displayLang)} • ${subject.cardCount} ${context.plural('card', subject.cardCount)}',
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
                    }, childCount: _filteredSubjects.length),
                  ),
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
                                  pillarId: pillarId,
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
        ),
      );
    },
  );
}

  Widget _buildCardPreview(CardModel card, Color pillarColor, String displayLang) {
    if (_currentSubject == null && _currentCollection == null) return Container();

    if (_currentSubject != null) {
      if (_currentSubject!.isNumbers) {
        return NumberGrid(
          displayChar: card.getNumericalChar(displayLang),
          fontSize: 40,
          color: pillarColor,
        );
      } else if (_currentSubject!.isDivision) {
        final parts = card.divisionParts ?? [0, 1];
        return DivisionGrid(
          a: parts[0],
          b: parts[1],
          languageCode: displayLang,
          fontSize: 24,
          color: pillarColor,
        );
      } else if (_currentSubject!.isMultiplication) {
        final parts = card.multiplicationParts ?? [1, 0];
        return MultiplicationGrid(
          a: parts[0],
          b: parts[1],
          languageCode: displayLang,
          fontSize: 24,
          color: pillarColor,
        );
      } else if (_currentSubject!.isSubtraction) {
        return SubtractionGrid(
          totalSum: card.numericalAnswer,
          maxOperand: _currentSubject!.maxOperand,
          iconSize: 18,
        );
      } else if (_currentSubject!.isAddition) {
        return AdditionGrid(
          totalSum: card.numericalAnswer,
          maxOperand: _currentSubject!.maxOperand,
          iconSize: 18,
        );
      } else if (_currentSubject!.isCounting) {
        return CountingGrid(
          count: card.numericalAnswer,
          iconSize: 24,
        );
      }
    }

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
