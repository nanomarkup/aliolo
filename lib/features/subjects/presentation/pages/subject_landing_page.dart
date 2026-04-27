import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/core/theme/aliolo_layout_tokens.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/folder_model.dart';
import 'package:aliolo/data/models/collection_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/math_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:aliolo/data/services/filter_service.dart';
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/data/services/subject_usage_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/utils/session_bucket_sampler.dart';
import 'package:aliolo/core/utils/card_sorting.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/core/widgets/aliolo_compact_dropdown.dart';
import 'package:aliolo/core/widgets/card_media_content.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:aliolo/core/widgets/card_renderer.dart';
import 'package:aliolo/features/testing/presentation/pages/learn_page.dart';
import 'package:aliolo/features/testing/presentation/pages/test_page.dart';
import 'package:aliolo/features/management/presentation/pages/subject_edit_page.dart';
import 'package:aliolo/features/management/presentation/pages/add_card_page.dart';
import 'package:aliolo/features/feedback/presentation/pages/feedback_page.dart';
import 'package:aliolo/features/settings/presentation/pages/premium_upgrade_page.dart';

class _EarlyRetestDecision {
  final bool retest;
  final bool remember;

  const _EarlyRetestDecision({
    required this.retest,
    required this.remember,
  });
}

class SubjectLandingPage extends StatefulWidget {
  final SubjectModel? subject;
  final FolderModel? folder;
  final CollectionModel? collection;
  final List<CardModel> cards;
  final String languageCode;
  final bool isReadOnly;

  const SubjectLandingPage({
    super.key,
    this.subject,
    this.folder,
    this.collection,
    required this.cards,
    required this.languageCode,
    this.isReadOnly = false,
  });

  @override
  State<SubjectLandingPage> createState() => _SubjectLandingPageState();
}

class _SubjectLandingPageState extends State<SubjectLandingPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _subService = getIt<SubscriptionService>();
  final _langService = getIt<TestingLanguageService>();
  final _filterService = getIt<FilterService>();
  final _progressService = getIt<ProgressService>();
  final _subjectUsageService = getIt<SubjectUsageService>();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _scrollController = ScrollController();
  bool _showBackToTop = false;

  SubjectModel? _currentSubject;
  FolderModel? _currentFolder;
  CollectionModel? _currentCollection;
  List<SubjectModel> _allSubjects = [];
  List<CardModel> _allCards = [];
  List<CardModel> _filteredCards = [];
  int _startLevel = 1;
  int _endLevel = CardService.maxLevel;
  List<SubjectModel> _filteredSubjects = [];
  bool _isLoading = false;
  bool _hasUpdated = false;
  late String _currentLanguageCode;

  @override
  void initState() {
    super.initState();
    _currentSubject = widget.subject;
    _currentFolder = widget.folder;
    _currentCollection = widget.collection;
    _allCards = widget.cards;
    _resetLevelFilter();
    _currentLanguageCode = _langService.currentLanguageCode.value;

    if (_currentCollection != null) {
      _fetchCollectionSubjects();
    } else {
      _applyFilters();
    }
    _cardService.addListener(_onServiceChange);
    _langService.currentLanguageCode.addListener(_onLanguageChange);
    _filterService.addListener(_onGlobalFilterChanged);
    _scrollController.addListener(() {
      if (_scrollController.offset > 400) {
        if (!_showBackToTop) setState(() => _showBackToTop = true);
      } else {
        if (_showBackToTop) setState(() => _showBackToTop = false);
      }
    });
  }

  void _onLanguageChange() {
    if (mounted) {
      setState(() {
        _currentLanguageCode = _langService.currentLanguageCode.value;
        _applyFilters();
      });
    }
  }

  void _onGlobalFilterChanged() {
    if (mounted) {
      setState(() {
        _applyFilters();
      });
    }
  }

  String? _earlyRetestPreferenceKey() {
    final subjectId = _currentSubject?.id;
    if (subjectId == null || subjectId.isEmpty) return null;
    return 'early_retest_allowed_$subjectId';
  }

  Future<bool> _canStartEarlyRetest() async {
    final preferenceKey = _earlyRetestPreferenceKey();
    if (preferenceKey != null) {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(preferenceKey) ?? false) {
        return true;
      }
    }

    if (!mounted) return false;
    final decision = await _showEarlyRetestDialog();
    if (decision == null || !decision.retest) return false;

    if (decision.remember && preferenceKey != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(preferenceKey, true);
    }

    return true;
  }

  Future<_EarlyRetestDecision?> _showEarlyRetestDialog() {
    var remember = false;
    return showDialog<_EarlyRetestDecision>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('No cards are due yet'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You are up to date for this subject. You can still retest all cards now.',
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: remember,
                        onChanged:
                            (value) => setDialogState(
                              () => remember = value ?? false,
                            ),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          "Don't show again for this subject",
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          () => Navigator.of(dialogContext).pop(
                            const _EarlyRetestDecision(
                              retest: false,
                              remember: false,
                            ),
                          ),
                      child: Text(context.t('cancel')),
                    ),
                    ElevatedButton(
                      onPressed:
                          () => Navigator.of(dialogContext).pop(
                            _EarlyRetestDecision(
                              retest: true,
                              remember: remember,
                            ),
                          ),
                      child: const Text('Retest anyway'),
                    ),
                  ],
                ),
          ),
    );
  }

  int get _minAvailableLevel {
    if (_allCards.isEmpty) return CardService.minLevel;
    return _allCards
        .map((card) => card.level)
        .reduce((value, element) => value < element ? value : element);
  }

  int get _maxAvailableLevel {
    if (_allCards.isEmpty) return CardService.maxLevel;
    return _allCards
        .map((card) => card.level)
        .reduce((value, element) => value > element ? value : element);
  }

  bool get _showLevelFilter =>
      (_currentSubject != null || _currentCollection != null) &&
      !(_currentSubject?.isMath ?? false) &&
      _allCards.isNotEmpty &&
      _minAvailableLevel < _maxAvailableLevel;

  void _resetLevelFilter() {
    _startLevel = _minAvailableLevel;
    _endLevel = _maxAvailableLevel;
  }

  Future<void> _fetchCollectionSubjects() async {
    if (_currentCollection == null) return;
    setState(() => _isLoading = true);
    try {
      final myId = _authService.currentUser?.serverId;
      final isOwner = _currentCollection?.ownerId == myId;

      List<SubjectModel> subjects = [];

      // 1. Always fetch the subjects actually IN the collection
      if (_currentCollection!.subjectIds.isNotEmpty) {
        subjects = await _cardService.getSubjectsByIds(
          _currentCollection!.subjectIds,
        );
      }

      // 2. If owner, also fetch dashboard subjects so they can add/remove from the collection
      if (isOwner) {
        final dashboardSubjects = await _cardService.getDashboardSubjects();
        for (var s in dashboardSubjects) {
          if (!subjects.any((existing) => existing.id == s.id)) {
            subjects.add(s);
          }
        }
      }

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
    _langService.currentLanguageCode.removeListener(_onLanguageChange);
    _filterService.removeListener(_onGlobalFilterChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onServiceChange() {
    if (mounted) {
      _refreshData(silent: true);
    }
  }

  Future<void> _refreshData({bool silent = false}) async {
    if (_currentSubject == null && _currentCollection == null) return;
    if (!silent) setState(() => _isLoading = true);

    if (_currentSubject != null) {
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
          _resetLevelFilter();
          _isLoading = false;
          _applyFilters();
        });
      }
    } else if (_currentCollection != null) {
      final cards = await _cardService.getCollectionCards(
        _currentCollection!.subjectIds,
      );
      final updatedCollection = await _cardService.getCollectionById(
        _currentCollection!.id,
      );

      if (mounted) {
        setState(() {
          _allCards = cards.map((sc) => sc.card).toList();
          if (updatedCollection != null) {
            _currentCollection = updatedCollection;
            _hasUpdated = true;
          }
          _resetLevelFilter();
          _isLoading = false;
          _applyFilters();
        });
      }
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final myId = _authService.currentUser?.serverId;
    final isOwner = _currentCollection?.ownerId == myId;

    setState(() {
      // Always update _filteredCards for count and session consistency
      _filteredCards =
          _allCards.where((c) {
            final promptMatches = c
                .getPrompt(_currentLanguageCode)
                .toLowerCase()
                .contains(query);
            final answerMatches = c
                .getAnswer(_currentLanguageCode)
                .toLowerCase()
                .contains(query);

            final matchesLevel = c.level >= _startLevel && c.level <= _endLevel;

            return (promptMatches || answerMatches) && matchesLevel;
          }).toList();

      sortCardsByLevelThenAnswer(_filteredCards, _currentLanguageCode);

      if (_currentCollection != null) {
        _filteredSubjects =
            _allSubjects.where((s) {
              if (!isOwner && !_currentCollection!.subjectIds.contains(s.id)) {
                return false;
              }

              final matchesName = s
                  .getName(_currentLanguageCode)
                  .toLowerCase()
                  .contains(query);
              final matchesAge =
                  _filterService.ageGroup == 'all' ||
                  s.ageGroup == _filterService.ageGroup;
              bool matchesCollection = true;
              if (_filterService.sourceFilter == 'mine') {
                matchesCollection = s.ownerId == myId;
              } else if (_filterService.sourceFilter == 'public') {
                matchesCollection = s.isPublic;
              } else if (_filterService.sourceFilter == 'favorites') {
                matchesCollection = s.isOnDashboard;
              }
              return matchesName && matchesAge && matchesCollection;
            }).toList();

        _filteredSubjects.sort((a, b) {
          final aSelected = _currentCollection!.subjectIds.contains(a.id);
          final bSelected = _currentCollection!.subjectIds.contains(b.id);
          if (aSelected && !bSelected) return -1;
          if (!aSelected && bSelected) return 1;
          return a
              .getName(_currentLanguageCode)
              .toLowerCase()
              .compareTo(b.getName(_currentLanguageCode).toLowerCase());
        });
      }
    });
  }

  Future<void> _toggleFavorite() async {
    if (_currentSubject == null && _currentCollection == null) return;

    if (_currentSubject != null) {
      final newState = !_currentSubject!.isOnDashboard;
      setState(() {
        _currentSubject!.isOnDashboard = newState;
        _hasUpdated = true;
      });
      try {
        await _cardService.toggleSubjectOnDashboard(
          _currentSubject!.id,
          newState,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _currentSubject!.isOnDashboard = !newState);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating favorite: $e')),
          );
        }
      }
    } else if (_currentCollection != null) {
      final newState = !_currentCollection!.isOnDashboard;
      setState(() {
        _currentCollection!.isOnDashboard = newState;
        _hasUpdated = true;
      });
      try {
        await _cardService.toggleCollectionOnDashboard(
          _currentCollection!.id,
          newState,
        );
      } catch (e) {
        if (mounted) {
          setState(() => _currentCollection!.isOnDashboard = !newState);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating favorite: $e')),
          );
        }
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
            title: Text(
              isCollection
                  ? context.t('delete_collection')
                  : context.t('delete_subject'),
            ),
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
                child: Text(
                  context.t('delete'),
                  style: const TextStyle(color: Colors.red),
                ),
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
      } else if (_currentSubject?.typeStr == 'collection') {
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
        if (_currentSubject!.isMath && _allCards.isEmpty) {
          final mathService = getIt<MathService>();
          final size = isTest ? user.testSessionSize : user.learnSessionSize;
          for (int i = 0; i < size; i++) {
            final problem = mathService.generateProblem(_currentSubject!);
            final card = mathService.createVirtualCard(problem, 1);
            sessionCards.add(
              SubjectCard(card: card, subject: _currentSubject!),
            );
          }
        } else {
          sessionCards =
              _filteredCards
                  .map((c) => SubjectCard(card: c, subject: _currentSubject!))
                  .toList();
        }
      }

      final lang = _currentLanguageCode.toLowerCase();
      if (!(_currentSubject?.isMath ?? false)) {
        final query = _searchController.text.toLowerCase();
        sessionCards =
            sessionCards.where((sc) {
              final c = sc.card;
              final promptMatches = c
                  .getPrompt(_currentLanguageCode)
                  .toLowerCase()
                  .contains(query);
              final answerMatches = c
                  .getAnswer(_currentLanguageCode)
                  .toLowerCase()
                  .contains(query);
              final matchesLevel =
                  c.level >= _startLevel && c.level <= _endLevel;

              final hasAnswer =
                  c.getAnswer(lang).isNotEmpty || c.getAnswer('en').isNotEmpty;

              return (promptMatches || answerMatches) &&
                  matchesLevel &&
                  hasAnswer;
            }).toList();
      }

      final size = isTest ? user.testSessionSize : user.learnSessionSize;
      var emptySessionMessage = 'No cards available for this session.';
      var userCanceledEarlyRetest = false;
      if (isTest && !(_currentSubject?.isMath ?? false)) {
        final candidateCards = List<SubjectCard>.from(sessionCards);
        final cardsById = {for (final sc in candidateCards) sc.card.id: sc};
        if (cardsById.isNotEmpty) {
          final selection = await _progressService
              .getReviewSessionCardSelection(
                cardIds: cardsById.keys.toList(),
                limit: size,
              );

          if (selection.succeeded) {
            sessionCards =
                selection.cardIds
                    .map((id) => cardsById[id])
                    .whereType<SubjectCard>()
                    .toList();
            if (sessionCards.isEmpty) {
              final shouldRetest = await _canStartEarlyRetest();
              if (shouldRetest) {
                sessionCards = SessionBucketSampler.sampleBucket(
                  candidateCards,
                  size,
                );
              } else {
                userCanceledEarlyRetest = true;
              }
            }
          } else {
            sessionCards = SessionBucketSampler.sampleBucket(
              candidateCards,
              size,
            );
          }
        }
      } else {
        sessionCards = SessionBucketSampler.sampleBucket(sessionCards, size);
      }

      if (sessionCards.isEmpty) {
        if (mounted && !userCanceledEarlyRetest) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(emptySessionMessage)));
        }
        return;
      }

      unawaited(
        _subjectUsageService.recordSessionStart(
          subjectIds: sessionCards.map((sc) => sc.card.subjectId),
          mode: isTest ? 'test' : 'learn',
        ),
      );

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    isTest
                        ? TestPage(
                          sessionCards: sessionCards,
                          languageCode: _currentLanguageCode,
                        )
                        : LearnPage(
                          sessionCards: sessionCards,
                          languageCode: _currentLanguageCode,
                        ),
          ),
        );
        if (_currentSubject != null) _refreshData(silent: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showFilterBottomSheet(BuildContext context, Color pillarColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            final isOwner =
                _currentCollection?.ownerId ==
                _authService.currentUser?.serverId;
            final isSmall = MediaQuery.sizeOf(context).width < 600;
            final showSourceAndAge = _currentCollection != null && isOwner;

            final filterRow =
                showSourceAndAge
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSmall) ...[
                          Text(
                            context.t('source'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          AlioloCompactDropdown<String>(
                            value: _filterService.sourceFilter,
                            items: {
                              'all': context.t('filter_all'),
                              'favorites': context.t('filter_favorites'),
                              'mine': context.t('filter_my_subjects'),
                              'public': context.t('filter_public_library'),
                            },
                            useFilledSurfaceStyle: true,
                            onChanged: (val) {
                              if (val != null) {
                                _filterService.updateSourceFilter(val);
                                setBottomSheetState(() {});
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                        ],
                        Text(
                          context.t('age'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        _buildCompactDropdown(
                          value: _filterService.ageGroup,
                          items: {
                            'all': context.t('age_all'),
                            '0_6': context.t('age_0_6'),
                            '7_14': context.t('age_7_14'),
                            '15_plus': context.t('age_15_plus'),
                          },
                          onChanged: (val) {
                            if (val != null) {
                              _filterService.updateAgeGroup(val);
                              setBottomSheetState(() {});
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    )
                    : const SizedBox.shrink();

            return Container(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.t('filters'),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_showLevelFilter) ...[
                      Text(
                        context.t('level'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildLevelDropdown(_startLevel, (val) {
                            if (val != null) {
                              setState(() {
                                _startLevel = val;
                                if (_endLevel < _startLevel)
                                  _endLevel = _startLevel;
                                _applyFilters();
                              });
                              setBottomSheetState(() {});
                            }
                          }),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: Text('-'),
                          ),
                          _buildLevelDropdown(_endLevel, (val) {
                            if (val != null) {
                              setState(() {
                                _endLevel = val;
                                if (_startLevel > _endLevel)
                                  _startLevel = _endLevel;
                                _applyFilters();
                              });
                              setBottomSheetState(() {});
                            }
                          }),
                          const SizedBox(width: 16),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _resetLevelFilter();
                                _applyFilters();
                              });
                              setBottomSheetState(() {});
                            },
                            child: Text(context.t('filter_all')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                    filterRow,
                    if (_allCards.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: Text(
                          '${_filteredCards.length} ${context.plural('card', _filteredCards.length)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: AlioloLayoutTokens.compactTileTitleSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompactDropdown({
    required String value,
    required Map<String, String> items,
    ValueChanged<String?>? onChanged,
    IconData? prefixIcon,
    String? selectedLabel,
    bool matchAnchorWidth = true,
    double? menuWidth,
    double verticalPadding = 8,
  }) {
    final validatedValue =
        items.containsKey(value)
            ? value
            : (items.isNotEmpty ? items.keys.first : '');
    final label = selectedLabel ?? items[validatedValue] ?? '';

    return LayoutBuilder(
      builder: (context, box) {
        return PopupMenuButton<String>(
          constraints:
              menuWidth != null
                  ? BoxConstraints(minWidth: menuWidth, maxWidth: menuWidth)
                  : (matchAnchorWidth
                      ? BoxConstraints(
                        minWidth: box.maxWidth,
                        maxWidth: box.maxWidth,
                      )
                      : null),
          onSelected: onChanged,
          position: PopupMenuPosition.under,
          color: Theme.of(context).colorScheme.surface,
          itemBuilder:
              (context) =>
                  items.entries
                      .map(
                        (e) => PopupMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                if (prefixIcon != null) ...[
                  Icon(prefixIcon, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down, size: 20, color: Colors.grey[600]),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _subService,
      builder: (context, _) {
        final isPremium = _subService.isPremium;
        final pillarId =
            _currentSubject?.pillarId ??
            _currentFolder?.pillarId ??
            _currentCollection?.pillarId ??
            1;
        final pillar = pillars.firstWhere(
          (p) => p.id == pillarId,
          orElse: () => pillars.first,
        );
        final pillarColor = pillar.getColor(getIt<ThemeService>().isDarkMode);
        const appBarColor = Colors.white;
        final isOwner =
            (_currentSubject != null &&
                _currentSubject!.ownerId ==
                    _authService.currentUser?.serverId) ||
            (_currentCollection != null &&
                _currentCollection!.ownerId ==
                    _authService.currentUser?.serverId);
        final title =
            _currentSubject?.getName(_currentLanguageCode) ??
            _currentFolder?.getName(_currentLanguageCode) ??
            _currentCollection?.getName(_currentLanguageCode) ??
            'Aliolo';

        final description =
            _currentSubject?.getDescription(_currentLanguageCode) ??
            _currentFolder?.getDescription(_currentLanguageCode) ??
            _currentCollection?.getDescription(_currentLanguageCode) ??
            '';

        final isSmallScreen = MediaQuery.sizeOf(context).width < 600;

        final backAction = IconButton(
          tooltip: context.t('back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context, _hasUpdated),
        );

        final favoriteAction =
            ((_currentSubject != null || _currentCollection != null) &&
                    !widget.isReadOnly)
                ? IconButton(
                  tooltip: context.t('favorite'),
                  icon: Icon(
                    (_currentSubject?.isOnDashboard ??
                            _currentCollection?.isOnDashboard ??
                            false)
                        ? Icons.star
                        : Icons.star_border,
                  ),
                  onPressed: _toggleFavorite,
                )
                : null;

        final editAction =
            (isOwner && !widget.isReadOnly)
                ? IconButton(
                  tooltip: context.t('edit'),
                  icon: const Icon(Icons.edit),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SubjectEditPage(
                              existingSubject:
                                  _currentSubject ??
                                  SubjectModel(
                                    id: _currentCollection!.id,
                                    pillarId: _currentCollection!.pillarId,
                                    ownerId: _currentCollection!.ownerId,
                                    isPublic: _currentCollection!.isPublic,
                                    createdAt: _currentCollection!.createdAt,
                                    updatedAt: _currentCollection!.updatedAt,
                                    name: _currentCollection!.name,
                                    names: _currentCollection!.names,
                                    description:
                                        _currentCollection!.description,
                                    descriptions:
                                        _currentCollection!.descriptions,
                                    folderId: _currentCollection!.folderId,
                                    typeStr: 'collection',
                                    linkedSubjectIds:
                                        _currentCollection!.subjectIds,
                                    isOnDashboard:
                                        _currentCollection!.isOnDashboard,
                                    ageGroup: _currentCollection!.ageGroup,
                                  ),
                              isCollectionMode: _currentCollection != null,
                            ),
                      ),
                    );
                    if (result == true) {
                      if (_currentSubject != null) _refreshData();
                      if (_currentCollection != null) {
                        if (context.mounted) Navigator.pop(context, true);
                      }
                    }
                  },
                )
                : null;

        final deleteAction =
            (isOwner && !widget.isReadOnly)
                ? IconButton(
                  tooltip: context.t('delete'),
                  icon: const Icon(Icons.delete),
                  onPressed: _confirmDeleteSubject,
                )
                : null;

        final feedbackAction = IconButton(
          tooltip: context.t('feedback'),
          icon: const Icon(Icons.feedback),
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
        );

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
                fontSize: 20,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            appBarColor: pillarColor,
            actions:
                isSmallScreen
                    ? [
                        IconButton(
                          tooltip: context.t('home'),
                          icon: Icon(pillar.getIconData(), color: appBarColor, size: 24),
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        ),
                        backAction,
                        if (favoriteAction != null) favoriteAction
                      ]
                    : [
                        IconButton(
                          tooltip: context.t('home'),
                          icon: Icon(pillar.getIconData(), color: appBarColor, size: 24),
                          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        ),
                        backAction,
                        if (favoriteAction != null) favoriteAction,
                        if (editAction != null) editAction,
                        if (deleteAction != null) deleteAction,
                        feedbackAction,
                      ],
            overflowActions:
                isSmallScreen
                    ? [
                      if (editAction != null) editAction,
                      if (deleteAction != null) deleteAction,
                      feedbackAction,
                    ]
                    : null,
            fixedBody:
                widget.isReadOnly
                    ? null
                    : LayoutBuilder(
                      builder: (context, constraints) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildActionButton(
                                      context: context,
                                      title: context.t('learn_mode_title'),
                                      icon: Icons.school,
                                      color: pillarColor,
                                      isPremiumFeature: false,
                                      isUserPremium: isPremium,
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
                                      isPremiumFeature: true,
                                      isUserPremium: isPremium,
                                      onTap: () {
                                        if (!isPremium) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      const PremiumUpgradePage(),
                                            ),
                                          );
                                        } else {
                                          _startSession(true);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (_currentSubject != null ||
                                  _currentCollection != null) ...[
                                const SizedBox(height: 16),
                                _buildFilterRow(
                                  isOwner,
                                  pillarColor,
                                  constraints,
                                  isPremium,
                                  pillarId,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            controller: _scrollController,
            floatingActionButton:
                _showBackToTop
                    ? FloatingActionButton(
                      onPressed: () {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                      },
                      backgroundColor: pillarColor,
                      child: const Icon(
                        Icons.arrow_upward,
                        color: Colors.white,
                      ),
                    )
                    : null,
            slivers: [
              // Scrollable Header Section
              SliverToBoxAdapter(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              description,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize:
                                    AlioloLayoutTokens.compactTileTitleSize,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ] else
                          const SizedBox(height: 16),
                        if (_currentSubject != null ||
                            _currentCollection != null) ...[
                          const SizedBox(height: 16),
                        ],
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_currentSubject == null && _currentCollection == null)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'This is a folder. You can use Learn/Test buttons above to practice all cards.',
                    ),
                  ),
                )
              else if (_currentCollection != null)
                if (_filteredSubjects.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text('No subjects found in this collection'),
                    ),
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
                              final cards = await _cardService
                                  .getCardsBySubject(subject.id);
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => SubjectLandingPage(
                                          subject: subject,
                                          cards: cards,
                                          languageCode: _currentLanguageCode,
                                          isReadOnly: true,
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
                                  if (isOwner && !widget.isReadOnly)
                                    Checkbox(
                                      value: _currentCollection!.subjectIds
                                          .contains(subject.id),
                                      activeColor: pillarColor,
                                      onChanged: (val) async {
                                        if (val == null) return;
                                        setState(() {
                                          if (val) {
                                            _currentCollection!.subjectIds.add(
                                              subject.id,
                                            );
                                          } else {
                                            _currentCollection!.subjectIds
                                                .remove(subject.id);
                                          }
                                          _hasUpdated = true;
                                        });
                                        await _cardService.addCollection(
                                          _currentCollection!,
                                          _currentCollection!.subjectIds,
                                        );
                                      },
                                    )
                                  else
                                    Icon(Icons.description, color: pillarColor),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subject.getName(_currentLanguageCode),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                        ),
                                        Text(
                                          '${pillars.firstWhere((p) => p.id == subject.pillarId, orElse: () => pillars.first).getTranslatedName(_currentLanguageCode)} • ${subject.cardCount} ${context.plural('card', subject.cardCount)}',
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
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final card = _filteredCards[index];
                      final isCardMine =
                          card.ownerId == _authService.currentUser?.serverId;
                      final answers = card.getAnswerList(_currentLanguageCode);
                      final answerText = answers
                          .map((a) => CardModel.capitalizeFirst(a))
                          .join(', ');

                      return InkWell(
                        onTap:
                            (isCardMine && !widget.isReadOnly)
                                ? () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => AddCardPage(
                                            existingCard: card,
                                            isReadOnly: false,
                                            pillarId: pillarId,
                                          ),
                                    ),
                                  );
                                  _refreshData(silent: true);
                                }
                                : () => _showZoomedCard(
                                  context,
                                  index,
                                  pillarColor,
                                  _currentLanguageCode,
                                ),
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
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _buildCardPreview(
                                      card,
                                      pillarColor,
                                      _currentLanguageCode,
                                      compactPreview: true,
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.fullscreen,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed:
                                              () => _showZoomedCard(
                                                context,
                                                index,
                                                pillarColor,
                                                _currentLanguageCode,
                                              ),
                                          tooltip: context.t('zoom'),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    answerText,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize:
                                          AlioloLayoutTokens
                                              .compactTileMetaSize,
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
          ),
        );
      },
    );
  }

  void _showZoomedCard(
    BuildContext context,
    int initialIndex,
    Color pillarColor,
    String displayLang,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: _ZoomedCardContent(
              initialIndex: initialIndex,
              cards: _filteredCards,
              pillarColor: pillarColor,
              displayLang: displayLang,
              subject: _currentSubject,
            ),
          ),
    );
  }

  Widget _buildCardPreview(
    CardModel card,
    Color pillarColor,
    String displayLang, {
    BoxFit fit = BoxFit.cover,
    AlignmentGeometry alignment = Alignment.center,
    bool compactPreview = false,
  }) {
    return CardRenderer(
      card: card,
      subject: _currentSubject,
      languageCode: displayLang,
      fallbackColor: pillarColor,
      fit: fit,
      alignment: alignment,
      compactPreview: compactPreview,
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPremiumFeature = false,
    bool isUserPremium = false,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
                if (isPremiumFeature && !isUserPremium) ...[
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.workspace_premium,
                    color: Colors.amber,
                    size: 16,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(
    bool isOwner,
    Color pillarColor,
    BoxConstraints constraints,
    bool isPremium,
    int pillarId,
  ) {
    return Row(
      children: [
        if (_currentCollection != null &&
            isOwner &&
            constraints.maxWidth >= 600) ...[
          SizedBox(
            width: 200,
            child: AlioloCompactDropdown<String>(
              value: _filterService.sourceFilter,
              items: {
                'all': context.t('filter_all'),
                'favorites': context.t('filter_favorites'),
                'mine': context.t('filter_my_subjects'),
                'public': context.t('filter_public_library'),
              },
              useFilledSurfaceStyle: true,
              onChanged: (val) async {
                if (val != null) {
                  _filterService.updateSourceFilter(val);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: constraints.maxWidth >= 600 ? 160 : 70,
          child: AlioloCompactDropdown<String>(
            value: _currentLanguageCode,
            items: Map.fromEntries(
              _langService.activeLanguageCodes.map(
                (l) => MapEntry(l, _langService.getLanguageName(l)),
              ),
            ),
            selectedLabel:
                constraints.maxWidth >= 600
                    ? _langService.getLanguageName(_currentLanguageCode)
                    : _currentLanguageCode.toUpperCase(),
            matchAnchorWidth: constraints.maxWidth >= 600,
            verticalPadding: constraints.maxWidth >= 600 ? 8 : 13,
            useFilledSurfaceStyle: true,
            onChanged: (val) async {
              if (val != null) {
                await _langService.updateCurrentLanguage(val);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            decoration: InputDecoration(
              hintText:
                  _currentCollection != null
                      ? context.t('search_subjects')
                      : context.t('search_cards'),
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon:
                  _searchController.text.isNotEmpty
                      ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Colors.grey.withValues(alpha: 0.5),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
            ),
            onChanged: (_) => _applyFilters(),
          ),
        ),
        if (isOwner && _currentSubject != null && !widget.isReadOnly) ...[
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: pillarColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white),
              onPressed: () async {
                if (!isPremium) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PremiumUpgradePage(),
                    ),
                  );
                  return;
                }
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => AddCardPage(
                          pillarId: pillarId,
                          initialSubjectId: _currentSubject!.id,
                        ),
                  ),
                );
                if (result == true) _refreshData();
              },
            ),
          ),
        ],
        if (!widget.isReadOnly) ...[
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: pillarColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              onPressed: () => _showFilterBottomSheet(context, pillarColor),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLevelDropdown(int value, ValueChanged<int?> onChanged) {
    final levels = List.generate(
      _maxAvailableLevel - _minAvailableLevel + 1,
      (i) => _minAvailableLevel + i,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          items:
              levels
                  .map(
                    (lv) => DropdownMenuItem(
                      value: lv,
                      child: Text(
                        switch (lv) {
                          1 => context.t('level_tier_1'),
                          2 => context.t('level_tier_2'),
                          3 => context.t('level_tier_3'),
                          _ => '$lv',
                        },
                        style: const TextStyle(
                          fontSize: AlioloLayoutTokens.appBarSubtitleSize,
                        ),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ZoomedCardContent extends StatefulWidget {
  final int initialIndex;
  final List<CardModel> cards;
  final Color pillarColor;
  final String displayLang;
  final SubjectModel? subject;

  const _ZoomedCardContent({
    required this.initialIndex,
    required this.cards,
    required this.pillarColor,
    required this.displayLang,
    this.subject,
  });

  @override
  State<_ZoomedCardContent> createState() => _ZoomedCardContentState();
}

class _ZoomedCardContentState extends State<_ZoomedCardContent> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _isAutoPlay = false;
  late int _autoplayDelaySeconds;
  Timer? _autoNextTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  StreamSubscription? _audioSubscription;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _autoplayDelaySeconds =
        getIt<AuthService>().currentUser?.learnAutoplayDelaySeconds ?? 3;

    _audioSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (_isAutoPlay && mounted) {
        _scheduleAutoNext();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupCurrentCardMedia();
    });
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _audioSubscription?.cancel();
    _audioPlayer.dispose();
    _videoController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _setupCurrentCardMedia() {
    _autoNextTimer?.cancel();
    _videoController?.dispose();
    _videoController = null;

    final card = widget.cards[_currentIndex];
    final vUrl = card.getVideoUrl(widget.displayLang);

    if (vUrl != null && vUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(vUrl));
      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {});
          _videoController!.play();
          _videoController!.addListener(_videoListener);
        }
      });
    } else {
      // If no video, maybe play initial audio if in some mode, but here we just wait for manual play or autoplay trigger
      if (_isAutoPlay) {
        _playCurrentAudio();
      }
    }
  }

  void _videoListener() {
    if (_videoController == null) return;
    if (_videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.isInitialized) {
      _videoController!.removeListener(_videoListener);
      if (_isAutoPlay && mounted) {
        _scheduleAutoNext();
      }
    }
  }

  void _scheduleAutoNext() {
    _autoNextTimer?.cancel();
    if (!_isAutoPlay || !mounted) return;

    _autoNextTimer = Timer(Duration(seconds: _autoplayDelaySeconds), () {
      if (mounted && _isAutoPlay) {
        if (_currentIndex < widget.cards.length - 1) {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } else {
          setState(() => _isAutoPlay = false);
        }
      }
    });
  }

  void _toggleAutoPlay() {
    setState(() {
      _isAutoPlay = !_isAutoPlay;
      if (_isAutoPlay) {
        if (_videoController != null && _videoController!.value.isInitialized) {
          if (_videoController!.value.position >=
              _videoController!.value.duration) {
            _scheduleAutoNext();
          } else {
            _videoController!.play();
          }
        } else {
          _playCurrentAudio();
        }
      } else {
        _autoNextTimer?.cancel();
        _audioPlayer.stop();
        _videoController?.pause();
      }
    });
  }

  void _playCurrentAudio() {
    final card = widget.cards[_currentIndex];
    final audioUrl = card.getAudioUrl(widget.displayLang);
    if (audioUrl != null && audioUrl.isNotEmpty) {
      _audioPlayer.play(UrlSource(audioUrl));
    } else if (_isAutoPlay) {
      _scheduleAutoNext();
    }
  }

  Future<void> _showDelayMenu(Offset globalPosition) async {
    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & MediaQuery.of(context).size,
      ),
      items:
          [1, 2, 3, 4, 5]
              .map(
                (s) => PopupMenuItem(value: s, child: Text(s.toString() + "s")),
              )
              .toList(),
    );
    if (selected != null) {
      setState(() {
        _autoplayDelaySeconds = selected;
        if (_isAutoPlay) _scheduleAutoNext();
      });
      getIt<AuthService>().updateLearnAutoplayDelay(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.cards[_currentIndex];
    final audioUrl = card.getAudioUrl(widget.displayLang);
    final hasAudio = audioUrl != null && audioUrl.isNotEmpty;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            if (_currentIndex < widget.cards.length - 1) {
              _pageController.nextPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (_currentIndex > 0) {
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: widget.cards.length,
                    onPageChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                        _setupCurrentCardMedia();
                      });
                    },
                    itemBuilder: (context, index) {
                      final itemCard = widget.cards[index];
                      final isCurrent = index == _currentIndex;
                      final audioUrl =
                          itemCard.getAudioUrl(widget.displayLang) ?? '';
                      final hasAudioUrl = audioUrl.isNotEmpty;
                      return Center(
                        child: CardMediaContent(
                          card: itemCard,
                          subject: widget.subject!,
                          languageCode: widget.displayLang,
                          headerColor: widget.pillarColor,
                          isMobile: isMobile,
                          videoController: isCurrent ? _videoController : null,
                          hasVideo: itemCard.hasVideoUrl(widget.displayLang),
                          images: itemCard.getImageUrls(widget.displayLang),
                          onPlayAudio:
                              hasAudioUrl
                                  ? () => _audioPlayer.play(UrlSource(audioUrl))
                                  : null,
                          hasAudio: hasAudioUrl,
                          hideAudioIcon: true,
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: widget.pillarColor.withValues(alpha: 0.1),
                    border: Border(
                      top: BorderSide(
                        color: widget.pillarColor.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 96),
                      Expanded(
                        child: Text(
                          card
                              .getAnswerList(widget.displayLang)
                              .map((a) => CardModel.capitalizeFirst(a))
                              .join(", "),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: widget.pillarColor,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.volume_up,
                          color:
                              hasAudio
                                  ? widget.pillarColor
                                  : Colors.grey.withValues(alpha: 0.3),
                          size: 28,
                        ),
                        onPressed:
                            hasAudio
                                ? () => _audioPlayer.play(UrlSource(audioUrl))
                                : null,
                        tooltip: context.t("play_audio"),
                      ),
                      GestureDetector(
                        onLongPressStart:
                            (details) => _showDelayMenu(details.globalPosition),
                        child: IconButton(
                          icon: Icon(
                            _isAutoPlay
                                ? Icons.pause_circle
                                : Icons.play_circle,
                            color: widget.pillarColor,
                            size: 28,
                          ),
                          onPressed: _toggleAutoPlay,
                          tooltip: context.t("autoplay"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.grey, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          if (widget.cards.length > 1) ...[
            Positioned(
              left: 8,
              child: Opacity(
                opacity: _currentIndex <= 0 ? 0.3 : 1.0,
                child: IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 40,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                  onPressed:
                      _currentIndex <= 0
                          ? null
                          : () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                ),
              ),
            ),
            Positioned(
              right: 8,
              child: Opacity(
                opacity: _currentIndex >= widget.cards.length - 1 ? 0.3 : 1.0,
                child: IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 40,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.5),
                  ),
                  onPressed:
                      _currentIndex >= widget.cards.length - 1
                          ? null
                          : () {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
