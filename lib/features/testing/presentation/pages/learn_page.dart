import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/sound_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/aliolo_image.dart';
import 'package:aliolo/core/widgets/counting_grid.dart';
import 'package:aliolo/core/widgets/addition_grid.dart';
import 'package:aliolo/core/widgets/subtraction_grid.dart';
import 'package:aliolo/core/widgets/number_grid.dart';
import 'package:aliolo/core/widgets/multiplication_grid.dart';
import 'package:aliolo/core/widgets/division_grid.dart';
import 'package:aliolo/features/settings/presentation/pages/premium_upgrade_page.dart';

class LearnPage extends StatefulWidget {
  final List<SubjectCard> sessionCards;
  final String languageCode;

  const LearnPage({
    super.key,
    required this.sessionCards,
    required this.languageCode,
  });

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  late SubjectCard _currentSubjectCard;
  CardModel get _currentCard => _currentSubjectCard.card;
  SubjectModel get _subject => _currentSubjectCard.subject;

  // Media State
  List<String> _currentImages = [];
  int _currentImageIndex = 0;
  bool _showingVideo = false;

  // Session State
  List<SubjectCard> _sessionQueue = [];
  int _completedInSession = 0;
  int _totalInSession = 0;

  bool _isAutoPlay = false;
  bool _isAutoPlayWaiting = false;
  bool _canGoNext = false;
  Timer? _autoNextTimer;
  Timer? _cooldownTimer;
  StreamSubscription? _playerSubscription;

  final _authService = AuthService();
  final _soundService = SoundService();
  final _progressService = getIt<ProgressService>();
  final _keyboardFocusNode = FocusNode();

  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) windowManager.setResizable(true);

    final isPremium = getIt<SubscriptionService>().isPremium;
    _isAutoPlay =
        isPremium && (_authService.currentUser?.autoPlayEnabled ?? false);

    _sessionQueue = List.from(widget.sessionCards);

    _totalInSession = _sessionQueue.length;

    if (_sessionQueue.isNotEmpty) {
      _currentSubjectCard = _sessionQueue.first;
      _completedInSession++;
    }

    _playerSubscription = player.stream.completed.listen((completed) {
      if (completed && _isAutoPlay && !_isAutoPlayWaiting) {
        _scheduleAutoNext(afterMedia: true);
      }
    });

    if (_sessionQueue.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupMedia();
      });
    }
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (_canGoNext) {
        _nextCard();
      }
    }
  }

  void _setupMedia() {
    _autoNextTimer?.cancel();
    _cooldownTimer?.cancel();
    _isAutoPlayWaiting = false;
    setState(() => _canGoNext = false);

    _cooldownTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _canGoNext = true);
    });

    final lang = widget.languageCode.toLowerCase();
    final images = _currentCard.getImageUrls(lang);
    final video = _currentCard.getVideoUrl(lang);

    setState(() {
      _currentImages = images;
      _currentImageIndex = 0;
      _showingVideo = images.isEmpty && (video?.isNotEmpty ?? false);
    });

    _playInitialMedia();
  }

  Future<void> _playInitialMedia() async {
    await player.stop();
    final lang = widget.languageCode.toLowerCase();
    final audioUrl = _currentCard.getAudioUrl(lang);
    final videoUrl = _currentCard.getVideoUrl(lang);

    bool hasMedia = false;
    if (_showingVideo && videoUrl != null) {
      await player.open(Media(videoUrl));
      player.play();
      hasMedia = true;
    } else if (audioUrl != null) {
      await player.open(Media(audioUrl));
      player.play();
      hasMedia = true;
    }

    if (_isAutoPlay && !hasMedia) {
      _scheduleAutoNext(afterMedia: false);
    }
  }

  void _scheduleAutoNext({required bool afterMedia}) {
    if (!_isAutoPlay || _isAutoPlayWaiting) return;
    setState(() => _isAutoPlayWaiting = true);
    final delay =
        afterMedia ? const Duration(seconds: 2) : const Duration(seconds: 4);
    _autoNextTimer?.cancel();
    _autoNextTimer = Timer(delay, () {
      if (mounted && _isAutoPlay && _isAutoPlayWaiting) _nextCard();
    });
  }

  Future<void> _nextCard() async {
    if (!_canGoNext) return;
    _autoNextTimer?.cancel();
    _cooldownTimer?.cancel();
    setState(() => _isAutoPlayWaiting = false);
    player.stop();

    await _progressService.recordLearnProgress(
      cardId: _currentCard.id,
      subjectId: _currentCard.subjectId,
    );

    if (_sessionQueue.isNotEmpty) {
      _sessionQueue.removeAt(0);
    }

    if (_sessionQueue.isNotEmpty) {
      _completedInSession++;
      setState(() => _currentSubjectCard = _sessionQueue.first);
      _setupMedia();
    } else {
      _progressService.awardSubjectCompletionBonus(_totalInSession);
      _soundService.playCompleted();
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(context.t('session_complete')),
            content: Text(context.t('session_complete_description')),
            actions: [
              TextButton(
                onPressed: () {
                  navigator.pop();
                  navigator.pop();
                },
                child: Text(context.t('back_to_subjects')),
              ),
            ],
          ),
    );
  }

  void _showPeekSheet() {
    final lang = widget.languageCode.toLowerCase();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TRANSLATIONS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              ..._currentCard.localizedData.entries
                  .where((e) => e.key != lang)
                  .map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.key.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            e.value.prompt ?? '-',
                            style: const TextStyle(fontSize: 16),
                          ),
                          ...(() {
                            final ansRaw = e.value.answer ?? '-';
                            final answers =
                                ansRaw
                                    .split(';')
                                    .map((s) => s.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toList();
                            if (answers.isEmpty)
                              return [
                                const Text(
                                  '-',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ];

                            return answers.map(
                              (a) => Text(
                                CardModel.capitalizeFirst(a),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          })(),
                        ],
                      ),
                    );
                  }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageCode.toLowerCase();
    final pillar = pillars.firstWhere(
      (p) => p.id == _subject.pillarId,
      orElse: () => pillars.first,
    );
    final headerColor = pillar.getColor(getIt<ThemeService>().isDarkMode);

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        double progressValue =
            _totalInSession > 0 ? _completedInSession / _totalInSession : 0.0;

        return KeyboardListener(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                _subject.getName(widget.languageCode),
                style: const TextStyle(fontSize: 18),
              ),
              backgroundColor: headerColor,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                if (_currentCard.getAudioUrl(lang) != null)
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () async {
                      final url = _currentCard.getAudioUrl(lang);
                      if (url != null) {
                        await player.open(Media(url));
                        player.play();
                      }
                    },
                  ),
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        _isAutoPlay ? Icons.pause_circle : Icons.play_circle,
                      ),
                      if (!getIt<SubscriptionService>().isPremium)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.workspace_premium,
                              color: Colors.amber,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: () {
                    final sub = getIt<SubscriptionService>();
                    if (!sub.isPremium) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PremiumUpgradePage(),
                        ),
                      );
                      return;
                    }
                    final newVal = !_isAutoPlay;
                    _authService.updateAutoPlayPreference(newVal);
                    setState(() {
                      _isAutoPlay = newVal;
                      if (_isAutoPlay) {
                        _scheduleAutoNext(afterMedia: false);
                      } else {
                        _autoNextTimer?.cancel();
                        _isAutoPlayWaiting = false;
                      }
                    });
                  },
                ),
                if (!kIsWeb) const WindowControls(color: Colors.white),
              ],
            ),
            floatingActionButton:
                _canGoNext
                    ? FloatingActionButton.extended(
                      onPressed: _nextCard,
                      backgroundColor: headerColor,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        context.t('next'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    )
                    : null,
            body: Column(
              children: [
                // Integrated Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 32,
                  ),
                  color: headerColor.withValues(alpha: 0.05),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      ...(() {
                        final answers = _currentCard.getAnswerList(lang);
                        if (answers.isEmpty) return [const SizedBox.shrink()];

                        return [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                answers
                                    .map(
                                      (ans) => InkWell(
                                        onTap: () async {
                                          final url = _currentCard.getAudioUrl(
                                            lang,
                                          );
                                          if (url != null) {
                                            await player.open(Media(url));
                                            player.play();
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          child: Text(
                                            CardModel.capitalizeFirst(ans),
                                            style: TextStyle(
                                              fontSize:
                                                  answers.length > 1 ? 24 : 32,
                                              color: headerColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                          ),
                        ];
                      })(),
                    ],
                  ),
                ),
                LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 4,
                  backgroundColor: headerColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(headerColor),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Card(
                        elevation: 4,
                        clipBehavior: Clip.antiAlias,
                        color: headerColor.withValues(alpha: 0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: headerColor.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_showingVideo)
                              Video(controller: controller)
                            else if (_currentImages.isNotEmpty)
                              AlioloImage(
                                imageUrl: _currentImages[_currentImageIndex],
                                fit: BoxFit.contain,
                              )
                            else if (_subject.isDivision)
                              DivisionGrid(
                                a: _currentCard.divisionParts?[0] ?? 0,
                                b: _currentCard.divisionParts?[1] ?? 1,
                                languageCode: lang,
                                fontSize: 120,
                                color: headerColor,
                              )
                            else if (_subject.isMultiplication)
                              MultiplicationGrid(
                                a: _currentCard.multiplicationParts?[0] ?? 1,
                                b: _currentCard.multiplicationParts?[1] ?? 0,
                                languageCode: lang,
                                fontSize: 120,
                                color: headerColor,
                              )
                            else if (_subject.isNumbers)
                              NumberGrid(
                                displayChar: _currentCard.getNumericalChar(
                                  lang,
                                ),
                                fontSize: 120,
                                color: headerColor,
                              )
                            else if (_subject.isSubtraction)
                              SubtractionGrid(
                                totalSum: _currentCard.numericalAnswer,
                                maxOperand: _subject.maxOperand,
                                iconSize: 60,
                              )
                            else if (_subject.isAddition)
                              AdditionGrid(
                                totalSum: _currentCard.numericalAnswer,
                                maxOperand: _subject.maxOperand,
                                iconSize: 60,
                              )
                            else if (_currentCard.subjectId ==
                                    '68232807-b9cd-4cff-872c-c398444f85e2' ||
                                _currentCard.subjectId ==
                                    'c3548727-65f4-4e0c-939c-56135b4eb543')
                              CountingGrid(
                                count: _currentCard.numericalAnswer,
                                iconSize: 60,
                              )
                            else
                              const Icon(
                                Icons.image_not_supported,
                                size: 100,
                                color: Colors.grey,
                              ),
                            if (!_showingVideo &&
                                _currentImages.length > 1) ...[
                              Positioned(
                                left: 10,
                                top: 0,
                                bottom: 0,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    color: Colors.black26,
                                    size: 40,
                                  ),
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _currentImageIndex =
                                                (_currentImageIndex -
                                                    1 +
                                                    _currentImages.length) %
                                                _currentImages.length,
                                      ),
                                ),
                              ),
                              Positioned(
                                right: 10,
                                top: 0,
                                bottom: 0,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.black26,
                                    size: 40,
                                  ),
                                  onPressed:
                                      () => setState(
                                        () =>
                                            _currentImageIndex =
                                                (_currentImageIndex + 1) %
                                                _currentImages.length,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _cooldownTimer?.cancel();
    _playerSubscription?.cancel();
    _keyboardFocusNode.dispose();
    player.dispose();
    super.dispose();
  }
}
