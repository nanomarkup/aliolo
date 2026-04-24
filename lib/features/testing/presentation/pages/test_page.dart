import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/data/services/subject_usage_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:aliolo/data/services/sound_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/core/widgets/card_renderer.dart';
import 'package:aliolo/core/widgets/card_media_content.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/math_service.dart';
import 'package:aliolo/features/settings/presentation/pages/premium_upgrade_page.dart';
import 'package:aliolo/features/testing/domain/test_mode.dart';

class TestOption {
  final String text;
  final String? imageUrl;
  final String id;
  final CardModel? card;

  TestOption({required this.text, this.imageUrl, required this.id, this.card});
}

class TestPage extends StatefulWidget {
  final List<SubjectCard> sessionCards;
  final String languageCode;

  const TestPage({
    super.key,
    required this.sessionCards,
    required this.languageCode,
  });

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final _authService = getIt<AuthService>();
  final _progressService = getIt<ProgressService>();
  final _subjectUsageService = getIt<SubjectUsageService>();
  final _soundService = getIt<SoundService>();

  late List<SubjectCard> _sessionQueue;
  late SubjectCard _currentSubjectCard;
  late CardModel _currentCard;
  late SubjectModel _subject;

  List<TestOption> _options = [];
  String _correctAnswerId = '';
  String _correctAnswerText = '';
  TestModeChoice _selectedMode = TestModeChoice.questionToAnswer;
  TestDirection _currentDirection = TestDirection.questionToAnswer;
  int _selectedIndex = -1;
  bool _isAnswered = false;
  bool _isCorrect = false;

  int _completedInSession = 0;
  int _totalInSession = 0;
  int _sessionCorrect = 0;
  bool _isSessionFinished = false;
  bool _isAdvancing = false;

  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasVideo = false;
  List<String> _currentImages = [];
  int _currentMediaIndex = 0;

  final _keyboardFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _gridScrollController = ScrollController();
  bool _isAutoPlay = false;
  bool _isMediaAutoPlayMuted = false;
  bool _isAutoPlayWaiting = false;
  final _random = Random();

  int _autoPlayingOptionIndex = -1;
  StreamSubscription? _playerSubscription;
  Timer? _optionAutoplayTimer;
  final Map<String, VideoPlayerController> _optionVideoControllers = {};
  VideoPlayerController? _activeOptionVideoController;
  VoidCallback? _activeOptionVideoListener;
  int _optionAutoplayGeneration = 0;
  int _optionAudioAutoplayGeneration = -1;
  bool _optionVisualReady = false;
  bool _optionPlaybackDone = false;
  bool _optionAdvanceScheduled = false;

  late String _languageCode;

  @override
  void initState() {
    super.initState();
    _languageCode = getIt<TestingLanguageService>().currentLanguageCode.value;
    final isPremium = getIt<SubscriptionService>().isPremium;
    _isAutoPlay =
        isPremium && (_authService.currentUser?.autoPlayEnabled ?? false);
    _isMediaAutoPlayMuted =
        _authService.currentUser?.mediaAutoPlayMuted ?? false;
    _selectedMode = parseTestModeChoice(_authService.currentUser?.testMode);

    _audioPlayer.onPlayerComplete.listen((_) {
      if (_optionAudioAutoplayGeneration == _optionAutoplayGeneration) {
        _optionAudioAutoplayGeneration = -1;
        _markOptionPlaybackDone(_optionAutoplayGeneration);
      }
    });

    _sessionQueue = List.from(widget.sessionCards)..shuffle();
    _totalInSession = _sessionQueue.length;
    _setupNextCard();
  }

  void _setupNextCard() {
    if (_sessionQueue.isEmpty) {
      _finishSession();
      return;
    }
    _completedInSession++;
    _isAdvancing = false;
    _currentDirection = _selectedMode.resolve(_random);

    // Scroll to top for both main page and grid area when new card loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      if (_gridScrollController.hasClients) {
        _gridScrollController.jumpTo(0);
      }
    });

    _currentSubjectCard = _sessionQueue.removeAt(0);
    _currentCard = _currentSubjectCard.card;
    _subject = _currentSubjectCard.subject;

    _selectedIndex = -1;
    _isAnswered = false;
    _isCorrect = false;
    _isAutoPlayWaiting = false;
    _stopOptionsAutoplay();

    _setupMCQ();
  }

  void _stopOptionsAutoplay() {
    _optionAutoplayTimer?.cancel();
    _optionAutoplayTimer = null;
    _optionAudioAutoplayGeneration = -1;
    _detachActiveOptionVideoListener();
    _activeOptionVideoController?.pause();
    _activeOptionVideoController = null;
    setState(() => _autoPlayingOptionIndex = -1);
  }

  void _startOptionsAutoplay() {
    if (!_isReverseMode || _isMediaAutoPlayMuted) return;
    final lang = _languageCode.toLowerCase();
    final hasOptionMedia = _options.any((option) {
      final card = option.card;
      if (card == null) return false;
      final hasImage =
          card.primaryImageUrl(lang) != null ||
          card.primaryImageUrl('global') != null ||
          card.primaryImageUrl('en') != null;
      final hasDisplayText = card.getDisplayText(lang).trim().isNotEmpty;
      return (card.getVideoUrl(lang)?.isNotEmpty ?? false) ||
          (card.getAudioUrl(lang)?.isNotEmpty ?? false) ||
          hasImage ||
          card.isSpecialRenderer ||
          card.isCountingRenderer ||
          card.isColors ||
          hasDisplayText;
    });
    if (!hasOptionMedia) return;

    if (_options.isNotEmpty) {
      _playOptionSequentially(0);
    }
  }

  Future<void> _playOptionSequentially(int index) async {
    if (_isAnswered || !mounted) return;
    if (index >= _options.length) {
      _stopOptionsAutoplay();
      return;
    }

    _optionAutoplayTimer?.cancel();
    _optionAudioAutoplayGeneration = -1;
    _detachActiveOptionVideoListener();
    await _audioPlayer.stop();
    await _activeOptionVideoController?.pause();
    _activeOptionVideoController = null;
    _optionAutoplayGeneration++;
    _optionVisualReady = false;
    _optionPlaybackDone = false;
    _optionAdvanceScheduled = false;
    final generation = _optionAutoplayGeneration;

    setState(() => _autoPlayingOptionIndex = index);
    final opt = _options[index];
    final card = opt.card;
    if (card == null) {
      _markOptionVisualReady(generation);
      _markOptionPlaybackDone(generation);
      return;
    }

    final lang = _languageCode.toLowerCase();
    final videoUrl = card.getVideoUrl(lang);
    if (videoUrl != null && videoUrl.isNotEmpty) {
      final controller = await _ensureOptionVideoController(card);
      if (!mounted ||
          _isAnswered ||
          _autoPlayingOptionIndex != index ||
          generation != _optionAutoplayGeneration) {
        return;
      }
      _activeOptionVideoController = controller;
      _markOptionVisualReady(generation);
      _activeOptionVideoListener = () {
        final value = controller.value;
        if (!value.isInitialized || value.isPlaying) return;
        if (value.position >= value.duration &&
            value.duration > Duration.zero) {
          _detachActiveOptionVideoListener();
          _markOptionPlaybackDone(generation);
        }
      };
      controller.addListener(_activeOptionVideoListener!);
      await controller.seekTo(Duration.zero);
      await controller.play();
      return;
    }

    unawaited(_prepareOptionVisualReady(card, generation));

    final audioUrl = card.getAudioUrl(lang);
    if (audioUrl != null && audioUrl.isNotEmpty) {
      _optionAudioAutoplayGeneration = generation;
      try {
        await _audioPlayer.play(UrlSource(audioUrl));
      } catch (_) {
        if (_optionAudioAutoplayGeneration == generation) {
          _optionAudioAutoplayGeneration = -1;
          _markOptionPlaybackDone(generation);
        }
      }
      return;
    }

    _markOptionPlaybackDone(generation);
  }

  void _scheduleNextOption() {
    if (_autoPlayingOptionIndex == -1 || _isAnswered || !mounted) return;

    _optionAutoplayTimer?.cancel();
    _optionAutoplayTimer = Timer(const Duration(seconds: 1), () {
      _playOptionSequentially(_autoPlayingOptionIndex + 1);
    });
  }

  Future<void> _prepareOptionVisualReady(CardModel card, int generation) async {
    final lang = _languageCode.toLowerCase();
    final imageUrl =
        card.primaryImageUrl(lang) ??
        card.primaryImageUrl('global') ??
        card.primaryImageUrl('en');

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        if (!imageUrl.toLowerCase().endsWith('.svg')) {
          await precacheImage(NetworkImage(imageUrl), context);
        } else {
          await WidgetsBinding.instance.endOfFrame;
        }
      } catch (_) {
        // Fall through and let the fallback count as ready.
      }
      _markOptionVisualReadyOnNextFrame(generation);
      return;
    }

    final hasDisplayText = card.getDisplayText(lang).trim().isNotEmpty;
    if (card.isSpecialRenderer ||
        card.isCountingRenderer ||
        card.isColors ||
        hasDisplayText) {
      _markOptionVisualReadyOnNextFrame(generation);
      return;
    }

    _markOptionVisualReady(generation);
  }

  void _markOptionVisualReadyOnNextFrame(int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markOptionVisualReady(generation);
    });
  }

  void _markOptionVisualReady(int generation) {
    if (!mounted ||
        generation != _optionAutoplayGeneration ||
        _optionVisualReady) {
      return;
    }
    _optionVisualReady = true;
    _maybeAdvanceOption(generation);
  }

  void _markOptionPlaybackDone(int generation) {
    if (!mounted ||
        generation != _optionAutoplayGeneration ||
        _optionPlaybackDone) {
      return;
    }
    _optionPlaybackDone = true;
    _maybeAdvanceOption(generation);
  }

  void _maybeAdvanceOption(int generation) {
    if (!mounted ||
        generation != _optionAutoplayGeneration ||
        _autoPlayingOptionIndex == -1 ||
        _isAnswered ||
        _optionAdvanceScheduled ||
        !_optionVisualReady ||
        !_optionPlaybackDone) {
      return;
    }
    _optionAdvanceScheduled = true;
    _scheduleNextOption();
  }

  void _detachActiveOptionVideoListener() {
    if (_activeOptionVideoController != null &&
        _activeOptionVideoListener != null) {
      _activeOptionVideoController!.removeListener(_activeOptionVideoListener!);
    }
    _activeOptionVideoListener = null;
  }

  Future<VideoPlayerController> _ensureOptionVideoController(
    CardModel card,
  ) async {
    final existing = _optionVideoControllers[card.id];
    if (existing != null) return existing;

    final videoUrl = card.getVideoUrl(_languageCode.toLowerCase())!;
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    _optionVideoControllers[card.id] = controller;
    await controller.initialize();
    if (mounted) {
      setState(() {});
    }
    return controller;
  }

  Future<void> _prepareOptionVideoControllers(List<TestOption> options) async {
    final lang = _languageCode.toLowerCase();
    final futures =
        options
            .map((option) => option.card)
            .whereType<CardModel>()
            .where((card) => card.getVideoUrl(lang)?.isNotEmpty ?? false)
            .map(_ensureOptionVideoController)
            .toList();

    if (futures.isEmpty) return;
    await Future.wait(futures);
  }

  Future<void> _disposeOptionVideoControllers() async {
    _detachActiveOptionVideoListener();
    _activeOptionVideoController = null;
    final controllers = _optionVideoControllers.values.toList();
    _optionVideoControllers.clear();
    for (final controller in controllers) {
      await controller.dispose();
    }
  }

  Future<void> _setupMCQ() async {
    _correctAnswerText = _getDisplayAnswer(_currentCard);
    _correctAnswerId = _currentCard.id;
    final user = _authService.currentUser;
    final isReverseMode = _currentDirection == TestDirection.answerToQuestion;

    List<TestOption> options = [];

    final List<CardModel> allInSubject =
        _currentCard.mathOptions != null
            ? widget.sessionCards.map((sc) => sc.card).toList()
            : await CardService().getCardsBySubject(_currentCard.subjectId);

    if (isReverseMode) {
      final sourceCards =
          allInSubject.where((c) => c.id != _currentCard.id).toList();
      sourceCards.shuffle();
      final optCount = user?.optionsCount ?? 6;
      final selectedCards = sourceCards.take(optCount - 1).toList();

      options =
          selectedCards
              .map(
                (c) =>
                    TestOption(text: _getDisplayAnswer(c), card: c, id: c.id),
              )
              .toList();

      options.add(
        TestOption(
          text: _correctAnswerText,
          card: _currentCard,
          id: _currentCard.id,
        ),
      );

      options.shuffle();
    } else if (_currentCard.mathOptions != null) {
      _correctAnswerId = _currentCard.numericalAnswer.toString();
      List<String> mathOpts = _currentCard.mathOptions ?? [];

      if (mathOpts.isEmpty) {
        // Try to get options from other cards in the subject first
        final otherAnswers =
            allInSubject
                .map((c) => c.numericalAnswer.toString())
                .where((v) => v != _correctAnswerId && v != '0')
                .toSet()
                .toList();

        if (otherAnswers.isNotEmpty) {
          otherAnswers.shuffle();
          final optCount = user?.optionsCount ?? 6;
          final selected = otherAnswers.take(optCount - 1).toList();
          selected.add(_correctAnswerId);
          selected.shuffle();
          mathOpts = selected;
        } else {
          // Purely dynamic (no cards in subject yet), fallback to generated
          final optCount = user?.optionsCount ?? 6;
          mathOpts = MathService().generateDistractors(
            _currentCard.numericalAnswer,
            optCount,
          );
        }
      }
      options = mathOpts.map((o) => TestOption(text: o, id: o)).toList();
    } else {
      final lang = _languageCode.toLowerCase();
      final currentAnswers =
          _currentCard.getAnswerList(lang).map((e) => e.toLowerCase()).toSet();

      final distractors =
          allInSubject.where((c) => c.id != _currentCard.id).where((c) {
            final otherAnswers =
                c.getAnswerList(lang).map((e) => e.toLowerCase()).toSet();
            // Only include as distractor if there's no overlap in answers
            return otherAnswers.intersection(currentAnswers).isEmpty;
          }).toList();
      distractors.shuffle();

      final optCount = user?.optionsCount ?? 6;
      final selectedDistractors = distractors.take(optCount - 1).toList();

      options =
          selectedDistractors
              .map(
                (c) => TestOption(
                  text: _getDisplayAnswer(c),
                  imageUrl: c.primaryImageUrl(widget.languageCode),
                  id: c.id,
                ),
              )
              .toList();

      options.add(
        TestOption(
          text: _correctAnswerText,
          imageUrl: _currentCard.primaryImageUrl(widget.languageCode),
          id: _currentCard.id,
        ),
      );

      options.shuffle();
    }

    await _disposeOptionVideoControllers();

    if (mounted) {
      setState(() {
        _options = options;
        final lang = _languageCode.toLowerCase();
        _currentImages = _currentCard.getImageUrls(lang);
        _currentMediaIndex = 0;
        final videoUrl = _currentCard.getVideoUrl(lang);

        _videoController?.dispose();
        _videoController = null;

        if (videoUrl != null && videoUrl.isNotEmpty) {
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(videoUrl),
          );
          _videoController!.initialize().then((_) {
            if (mounted) {
              setState(() {
                _hasVideo = true;
              });
              if (!_isMediaAutoPlayMuted) {
                _videoController!.play();
              }
            }
          });
        } else {
          _hasVideo = false;
        }
      });
    }

    await _prepareOptionVideoControllers(options);

    final lang = _languageCode.toLowerCase();
    final audio = _currentCard.getAudioUrl(lang);
    final hasVisuals = _hasVideo || _currentImages.isNotEmpty;

    // Normal mode: Play if NO visuals
    // Reverse mode: Play if HAS visuals (as per new requirement)
    bool shouldPlay = false;
    if (audio != null &&
        !_currentCard.isSpecialRenderer &&
        !_currentCard.isCountingRenderer) {
      if (!_isReverseMode && !hasVisuals) {
        shouldPlay = true;
      } else if (_isReverseMode && hasVisuals) {
        shouldPlay = true;
      }
    }

    if (!_isMediaAutoPlayMuted && shouldPlay && audio != null) {
      _audioPlayer.play(UrlSource(audio));
    }

    if (_isReverseMode && !_isMediaAutoPlayMuted) {
      _startOptionsAutoplay();
    }
  }

  bool get _isReverseMode =>
      _currentDirection == TestDirection.answerToQuestion;

  Future<void> _setSelectedMode(TestModeChoice mode) async {
    if (_selectedMode == mode) return;
    setState(() => _selectedMode = mode);
    await _authService.updateTestMode(mode.storageValue);
  }

  Future<void> _toggleMediaAutoPlayMuted() async {
    final newValue = !_isMediaAutoPlayMuted;
    setState(() => _isMediaAutoPlayMuted = newValue);
    await _authService.updateMediaAutoPlayMuted(newValue);

    if (newValue) {
      _stopOptionsAutoplay();
      await _audioPlayer.stop();
      await _videoController?.pause();
    }
  }

  Widget _buildModeMenuButton(Color headerColor) {
    return PopupMenuButton<TestModeChoice>(
      tooltip: 'Testing mode',
      initialValue: _selectedMode,
      icon: Icon(_selectedMode.icon),
      onSelected: _setSelectedMode,
      itemBuilder: (context) {
        return TestModeChoice.values.map((mode) {
          final selected = _selectedMode == mode;
          return PopupMenuItem<TestModeChoice>(
            value: mode,
            child: Row(
              children: [
                Icon(
                  mode.icon,
                  size: 20,
                  color: selected ? headerColor : Colors.grey[700],
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(mode.label)),
                if (selected) Icon(Icons.check, size: 18, color: headerColor),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildMediaMuteControl() {
    return IconButton(
      tooltip: _isMediaAutoPlayMuted ? 'Unmute auto-play' : 'Mute auto-play',
      icon: Icon(_isMediaAutoPlayMuted ? Icons.volume_off : Icons.volume_up),
      onPressed: _toggleMediaAutoPlayMuted,
    );
  }

  Widget _buildForwardMediaContent({
    required BuildContext context,
    required bool isMobile,
    required Color headerColor,
    required String lang,
  }) {
    final audioUrl = _currentCard.getAudioUrl(lang);
    final hasVisuals = _hasVideo || _currentImages.isNotEmpty;
    // In normal mode, if visuals are present, hide audio
    final effectivelyHasAudio =
        (audioUrl != null && audioUrl.isNotEmpty) &&
        (_isReverseMode || !hasVisuals);

    // Hide icon in CardMediaContent if:
    // 1. Normal mode and has visuals (we don't want audio at all)
    // 2. Reverse mode and has visuals (we show it in the top header)
    final hideIconInContent = hasVisuals;

    return CardMediaContent(
      card: _currentCard,
      subject: _subject,
      languageCode: lang,
      headerColor: headerColor,
      isMobile: isMobile,
      videoController: _videoController,
      hasVideo: _hasVideo,
      images: _currentImages,
      mediaIndex: _currentMediaIndex,
      onMediaIndexChanged: (index) {
        if (mounted) {
          setState(() => _currentMediaIndex = index);
        }
      },
      onPlayAudio:
          effectivelyHasAudio
              ? () async {
                if (audioUrl.isNotEmpty) {
                  await _audioPlayer.play(UrlSource(audioUrl));
                }
              }
              : null,
      hasAudio: effectivelyHasAudio,
      hideAudioIcon: hideIconInContent,
      headerText:
          _isReverseMode
              ? _correctAnswerText
              : _currentCard.getPrompt(lang).trim(),
    );
  }

  Widget _buildQuestionHeader(BuildContext context, Color headerColor) {
    final lang = _languageCode.toLowerCase();
    final primaryText =
        _isReverseMode
            ? _correctAnswerText
            : _currentCard.getPrompt(lang).trim();
    final primaryTextColor =
        _isReverseMode && _isAnswered
            ? (_isCorrect ? Colors.green : Colors.red)
            : Theme.of(
              context,
            ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7);
    final primaryTextFontSize =
        _isReverseMode ? (_isAnswered ? 32.0 : 32.0) : 20.0;
    final primaryTextFontWeight =
        _isReverseMode && _isAnswered ? FontWeight.bold : FontWeight.w500;

    final secondaryWidget =
        _isAnswered
            ? (_isReverseMode
                ? const SizedBox.shrink()
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children:
                      _currentCard
                          .getAnswerList(lang)
                          .map(
                            (ans) => Text(
                              CardModel.capitalizeFirst(ans),
                              style: TextStyle(
                                fontSize:
                                    _currentCard.getAnswerList(lang).length > 1
                                        ? 24
                                        : 32,
                                color: _isCorrect ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                          .toList(),
                ))
            : (_isReverseMode
                ? const SizedBox.shrink()
                : Text(
                  '???',
                  style: TextStyle(
                    fontSize: 32,
                    color: headerColor.withValues(alpha: 0.3),
                    fontWeight: FontWeight.bold,
                  ),
                ));

    final audioUrl = _currentCard.getAudioUrl(lang);
    final hasAudio = audioUrl != null && audioUrl.isNotEmpty;
    final hasVisuals = _hasVideo || _currentImages.isNotEmpty;
    final showTopAudioIcon = _isReverseMode && hasVisuals && hasAudio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
      color: headerColor.withValues(alpha: 0.05),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            primaryText.isNotEmpty ? primaryText : ' ',
            style: TextStyle(
              fontSize: primaryTextFontSize,
              color: primaryTextColor,
              fontWeight: primaryTextFontWeight,
            ),
          ),
          if (showTopAudioIcon)
            IconButton(
              icon: Icon(Icons.volume_up, color: headerColor),
              onPressed: () => _audioPlayer.play(UrlSource(audioUrl)),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          const SizedBox(width: 12),
          secondaryWidget,
        ],
      ),
    );
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (_isAnswered && !_isAdvancing) {
        _nextCard();
      }
    } else {
      // Handle number keys 1-9
      final keyLabel = event.logicalKey.keyLabel;
      if (keyLabel.length == 1 && RegExp(r'[1-9]').hasMatch(keyLabel)) {
        final index = int.parse(keyLabel) - 1;
        if (index < _options.length && !_isAnswered) {
          _selectOption(index);
        }
      }
    }
  }

  String _getDisplayAnswer(CardModel card) {
    final lang = _languageCode.toLowerCase();
    final list = card.getAnswerList(lang);
    if (list.isNotEmpty) return CardModel.capitalizeFirst(list.first);

    final enList = card.getAnswerList('en');
    if (enList.isNotEmpty) return CardModel.capitalizeFirst(enList.first);

    return '';
  }

  Future<void> _selectOption(int index) async {
    if (_isAnswered) return;
    _stopOptionsAutoplay();
    _audioPlayer.stop();
    _videoController?.pause();
    final correct = _options[index].id == _correctAnswerId;
    setState(() {
      _selectedIndex = index;
      _isAnswered = true;
      _isCorrect = correct;
    });

    if (correct) {
      _sessionCorrect++;
      _soundService.playCorrect();
      await _progressService.recordReview(
        cardId: _currentCard.id,
        subjectId: _currentCard.subjectId,
        quality: 5,
      );
    } else {
      _soundService.playWrong();
      await _progressService.recordReview(
        cardId: _currentCard.id,
        subjectId: _currentCard.subjectId,
        quality: 0,
      );
    }

    if (_isAutoPlay && mounted) {
      _scheduleAutoNext();
    }
  }

  void _scheduleAutoNext() {
    _isAutoPlayWaiting = true;
    Future.delayed(Duration(milliseconds: _isCorrect ? 1000 : 2000), () {
      if (mounted && _isAutoPlayWaiting && _isAnswered) {
        _nextCard();
      }
    });
  }

  void _nextCard() {
    if (_isAdvancing) return;
    setState(() => _isAdvancing = true);

    if (_sessionQueue.isEmpty && _isAnswered) {
      _finishSession();
      return;
    }
    _setupNextCard();
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _finishSession() {
    if (_isSessionFinished) return;
    unawaited(
      _subjectUsageService.recordSessionComplete(
        subjectIds: widget.sessionCards.map((sc) => sc.card.subjectId),
        mode: 'test',
      ),
    );
    setState(() {
      _isSessionFinished = true;
    });
  }

  Widget _buildResultsView(Color headerColor) {
    final int failed = _completedInSession - _sessionCorrect;
    final double percent =
        _completedInSession > 0
            ? (_sessionCorrect / _completedInSession) * 100
            : 0;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          _subject.getName(_languageCode),
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: headerColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          if (!kIsWeb) const WindowControls(color: Colors.white),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t('session_complete'),
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildResultRow(
                      context.t('total_cards'),
                      '$_completedInSession',
                    ),
                    _buildResultRow(
                      context.t('correct_answers'),
                      '$_sessionCorrect',
                      color: Colors.green,
                    ),
                    _buildResultRow(
                      context.t('failed_answers'),
                      '$failed',
                      color: Colors.red,
                    ),
                    const Divider(height: 64),
                    Text(
                      '${percent.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 80,
                        fontWeight: FontWeight.bold,
                        color:
                            percent >= 70
                                ? Colors.green
                                : (percent >= 40 ? Colors.orange : Colors.red),
                      ),
                    ),
                    const SizedBox(height: 48),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.pop(context, true),
                        icon: const Icon(Icons.school),
                        label: Text(
                          context.t('back_to_subjects'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: headerColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = _languageCode.toLowerCase();
    final pillar = pillars.firstWhere(
      (p) => p.id == _subject.pillarId,
      orElse: () => pillars.first,
    );
    final headerColor = pillar.getColor(getIt<ThemeService>().isDarkMode);

    if (_isSessionFinished) {
      return _buildResultsView(headerColor);
    }

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
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(
                _subject.getName(_languageCode),
                style: const TextStyle(fontSize: 18),
              ),
              backgroundColor: headerColor,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                ),
                _buildMediaMuteControl(),
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
                      if (_isAutoPlay && _isAnswered && !_isAutoPlayWaiting) {
                        _scheduleAutoNext();
                      }
                    });
                  },
                ),
                _buildModeMenuButton(headerColor),
                if (!kIsWeb) const WindowControls(color: Colors.white),
              ],
            ),
            floatingActionButton: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: (_isAnswered && !_isAdvancing) ? 1.0 : 0.45,
              child: FloatingActionButton.extended(
                onPressed: (_isAnswered && !_isAdvancing) ? _nextCard : null,
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
              ),
            ),
            body: Column(
              children: [
                _buildQuestionHeader(context, headerColor),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 4,
                  backgroundColor: headerColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(headerColor),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isMobile = constraints.maxWidth < 800;
                      final correctImageUrl =
                          _currentCard.primaryImageUrl(lang) ??
                          _currentCard.primaryImageUrl('global') ??
                          _currentCard.primaryImageUrl('en');
                      final correctVideoUrl = _currentCard.getVideoUrl(lang);
                      final hasMeaningfulDisplayText = _currentCard
                          .hasMeaningfulDisplayText(lang);
                      final displayText =
                          hasMeaningfulDisplayText
                              ? _currentCard.getDisplayText(lang).trim()
                              : '';
                      final deduplicatedText =
                          (_correctAnswerText.isNotEmpty &&
                                  displayText.toLowerCase() ==
                                      _correctAnswerText.toLowerCase())
                              ? ''
                              : displayText;
                      final hasCorrectVisual =
                          _currentCard.isSpecialRenderer ||
                          _currentCard.isCountingRenderer ||
                          _currentCard.isColors ||
                          (correctVideoUrl != null &&
                              correctVideoUrl.isNotEmpty) ||
                          (correctImageUrl != null &&
                              correctImageUrl.isNotEmpty) ||
                          deduplicatedText.isNotEmpty;
                      final isAudioTest =
                          !hasCorrectVisual &&
                          (_currentCard.getAudioUrl(lang)?.isNotEmpty ?? false);

                      final audioUrl = _currentCard.getAudioUrl(lang);
                      final hasAudio = audioUrl != null && audioUrl.isNotEmpty;
                      final isSpecialAudioMode =
                          !_isReverseMode &&
                          deduplicatedText.isEmpty &&
                          (correctVideoUrl == null ||
                              correctVideoUrl.isEmpty) &&
                          (correctImageUrl == null ||
                              correctImageUrl.isEmpty) &&
                          hasAudio &&
                          !_currentCard.isSpecialRenderer &&
                          !_currentCard.isCountingRenderer &&
                          !_currentCard.isColors;

                      // Calculate the absolute maximum columns based on width
                      final maxPossibleColumns =
                          isAudioTest
                              ? (constraints.maxWidth / 300).floor().clamp(2, 4)
                              : (constraints.maxWidth / 400).floor().clamp(
                                2,
                                3,
                              );

                      // Balanced crossAxisCount logic:
                      // Distribute items as evenly as possible across rows.
                      final int numOptions = _options.length;
                      int crossAxisCount;
                      if (numOptions == 0) {
                        crossAxisCount = maxPossibleColumns;
                      } else if (numOptions <= maxPossibleColumns) {
                        crossAxisCount = numOptions;
                      } else {
                        final int rows =
                            (numOptions / maxPossibleColumns).ceil();
                        crossAxisCount = (numOptions / rows).ceil();
                      }
                      // Safety clamp
                      crossAxisCount = crossAxisCount.clamp(
                        2,
                        maxPossibleColumns,
                      );

                      final mediaContent = _buildForwardMediaContent(
                        context: context,
                        isMobile: isMobile,
                        headerColor: headerColor,
                        lang: lang,
                      );

                      final optionsTitle =
                          _isReverseMode
                              ? 'Select the matching card'
                              : context.t('select_an_answer');

                      final optionsContent = Container(
                        width:
                            _isReverseMode || isMobile || isSpecialAudioMode
                                ? double.infinity
                                : 350,
                        padding: EdgeInsets.all(isMobile ? 24 : 32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow:
                              isMobile
                                  ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, -5),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Text(
                              optionsTitle,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                                letterSpacing: 1.1,
                              ),
                            ),
                            if (isSpecialAudioMode) ...[
                              const SizedBox(height: 10),
                              IconButton(
                                icon: Icon(
                                  Icons.volume_up,
                                  size: 80,
                                  color: headerColor,
                                ),
                                onPressed: () async {
                                  if (audioUrl.isNotEmpty) {
                                    await _audioPlayer.play(
                                      UrlSource(audioUrl),
                                    );
                                  }
                                },
                              ),
                            ],
                            const SizedBox(height: 20),
                            if (_options.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24),
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_isReverseMode)
                              Expanded(
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const BouncingScrollPhysics(),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                        childAspectRatio:
                                            isAudioTest
                                                ? (isMobile ? 2.5 : 3.0)
                                                : 1.0,
                                      ),
                                  itemCount: _options.length,
                                  itemBuilder:
                                      (context, index) => _buildOptionButton(
                                        index,
                                        headerColor,
                                        isMobile,
                                        isAudioTest,
                                      ),
                                ),
                              )
                            else if (isMobile)
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 2.5,
                                    ),
                                itemCount: _options.length,
                                itemBuilder:
                                    (context, index) => _buildOptionButton(
                                      index,
                                      headerColor,
                                      isMobile,
                                      isAudioTest,
                                    ),
                              )
                            else
                              Expanded(
                                child: Center(
                                  child: ListView.separated(
                                    shrinkWrap: true,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _options.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 12),
                                    itemBuilder:
                                        (context, index) => _buildOptionButton(
                                          index,
                                          headerColor,
                                          isMobile,
                                          isAudioTest,
                                        ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );

                      if (_isReverseMode || isSpecialAudioMode) {
                        return Padding(
                          padding: EdgeInsets.all(isMobile ? 16 : 32),
                          child: optionsContent,
                        );
                      }

                      if (isMobile) {
                        return SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            children: [
                              if (!isSpecialAudioMode) mediaContent,
                              optionsContent,
                            ],
                          ),
                        );
                      }

                      final isLeft =
                          _authService.currentUser?.sidebarLeft ?? false;
                      return Row(
                        children:
                            isLeft
                                ? [
                                  optionsContent,
                                  if (!isSpecialAudioMode)
                                    Expanded(flex: 3, child: mediaContent),
                                ]
                                : [
                                  if (!isSpecialAudioMode)
                                    Expanded(flex: 3, child: mediaContent),
                                  optionsContent,
                                ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionButton(
    int index,
    Color headerColor,
    bool isMobile,
    bool isAudioTest,
  ) {
    final opt = _options[index];
    final isSelected = _selectedIndex == index;
    final isCorrect = opt.id == _correctAnswerId;
    Color? color;
    if (_isAnswered) {
      color =
          isCorrect
              ? getIt<ThemeService>().success
              : (isSelected ? getIt<ThemeService>().error : null);
    } else if (isSelected) {
      color = headerColor;
    } else if (_autoPlayingOptionIndex == index) {
      color = headerColor.withValues(alpha: 0.5);
    }

    if (_isReverseMode && opt.card != null) {
      final lang = _languageCode.toLowerCase();
      final optAudioUrl = opt.card!.getAudioUrl(lang);
      final hasOptAudio = optAudioUrl != null && optAudioUrl.isNotEmpty;
      final optVideoUrl = opt.card!.getVideoUrl(lang);
      final hasOptVideo = optVideoUrl != null && optVideoUrl.isNotEmpty;
      final optVideoController = _optionVideoControllers[opt.card!.id];

      return InkWell(
        onTap: () => _selectOption(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: color ?? Colors.grey[300]!, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: color?.withValues(alpha: 0.1),
          ),
          child:
              isAudioTest
                  ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkResponse(
                          onTap: () => _selectOption(index),
                          radius: isMobile ? 32 : 40,
                          hoverColor: headerColor.withValues(alpha: 0.1),
                          highlightShape: BoxShape.circle,
                          containedInkWell: false,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: isMobile ? 28 : 36,
                                fontWeight: FontWeight.bold,
                                color: headerColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.volume_up,
                          size: isMobile ? 36 : 52,
                          color:
                              hasOptAudio
                                  ? headerColor
                                  : Colors.grey.withValues(alpha: 0.3),
                        ),
                        onPressed:
                            hasOptAudio
                                ? () async {
                                  if (optAudioUrl.isNotEmpty) {
                                    await _audioPlayer.play(
                                      UrlSource(optAudioUrl),
                                    );
                                  }
                                }
                                : null,
                      ),
                    ],
                  )
                  : Stack(
                    children: [
                      Positioned.fill(
                        child:
                            hasOptVideo &&
                                    optVideoController != null &&
                                    optVideoController.value.isInitialized
                                ? ValueListenableBuilder(
                                  valueListenable: optVideoController,
                                  builder: (
                                    context,
                                    VideoPlayerValue value,
                                    _,
                                  ) {
                                    return Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        FittedBox(
                                          fit: BoxFit.contain,
                                          child: SizedBox(
                                            width: value.size.width,
                                            height: value.size.height,
                                            child: VideoPlayer(
                                              optVideoController,
                                            ),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              if (optVideoController
                                                  .value
                                                  .isPlaying) {
                                                optVideoController.pause();
                                              } else {
                                                if (optVideoController
                                                        .value
                                                        .position >=
                                                    optVideoController
                                                        .value
                                                        .duration) {
                                                  optVideoController.seekTo(
                                                    Duration.zero,
                                                  );
                                                }
                                                optVideoController.play();
                                              }
                                            },
                                          ),
                                        ),
                                        if (!value.isPlaying)
                                          IgnorePointer(
                                            child: Center(
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.35),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  Icons.play_arrow,
                                                  size: isMobile ? 40 : 52,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                )
                                : hasOptVideo
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : CardRenderer(
                                  card: opt.card!,
                                  subject: _subject,
                                  languageCode: _languageCode,
                                  fallbackColor: headerColor,
                                  fit: BoxFit.contain,
                                  textFontSize: isMobile ? 24 : 32,
                                  excludeText: _correctAnswerText,
                                  forceAudioIcon: false,
                                  onPlayAudio:
                                      hasOptAudio
                                          ? () async {
                                            if (optAudioUrl.isNotEmpty) {
                                              await _audioPlayer.play(
                                                UrlSource(optAudioUrl),
                                              );
                                            }
                                          }
                                          : null,
                                ),
                      ),
                      Positioned(
                        left: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
        ),
      );
    }

    // Dynamic font size based on text length
    double fontSize = isMobile ? 16 : 18;
    if (opt.text.length > 15) {
      fontSize = isMobile ? 12 : 14;
    } else if (opt.text.length > 10) {
      fontSize = isMobile ? 14 : 16;
    }

    return InkWell(
      onTap: () => _selectOption(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color ?? Colors.grey[300]!, width: 2),
          borderRadius: BorderRadius.circular(12),
          color: color?.withValues(alpha: 0.1),
        ),
        child: Row(
          children: [
            Text(
              '${index + 1}.',
              style: TextStyle(
                fontSize: fontSize * 0.8,
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                opt.text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _optionAutoplayTimer?.cancel();
    _playerSubscription?.cancel();
    _detachActiveOptionVideoListener();
    for (final controller in _optionVideoControllers.values) {
      controller.dispose();
    }
    _keyboardFocusNode.dispose();
    _scrollController.dispose();
    _gridScrollController.dispose();
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
