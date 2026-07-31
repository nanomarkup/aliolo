import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:video_player/video_player.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/sound_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/data/services/subject_usage_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/widgets/card_media_content.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/features/settings/presentation/pages/premium_upgrade_page.dart';
import 'package:aliolo/features/testing/presentation/widgets/session_completion_window.dart';

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
  static const List<int> _autoPlayDelayOptions = <int>[1, 2, 3, 4, 5];

  late PageController _pageController;
  int _currentIndex = 0;

  CardModel get _currentCard => _sessionQueue[_currentIndex].card;
  SubjectModel get _subject => _sessionQueue[_currentIndex].subject;

  // Media State
  bool _hasVideo = false;

  // Session State
  List<SubjectCard> _sessionQueue = [];
  final Set<String> _recordedCardIds = {};
  int _completedInSession = 0;
  int _totalInSession = 0;

  bool _isAutoPlay = false;
  bool _isMediaAutoPlayMuted = false;
  bool _isAutoPlayWaiting = false;
  bool _canGoNext = false;
  bool _isAdvancing = false;
  bool _isSessionFinished = false;
  int _learnAutoplayDelaySeconds = 3;
  Timer? _autoNextTimer;
  Timer? _cooldownTimer;
  StreamSubscription? _playerSubscription;
  int _mediaSetupToken = 0;
  int _autoPlayAudioToken = -1;
  bool _autoPlayVisualReady = false;
  bool _autoPlayPlaybackDone = false;
  bool _autoPlayScheduledForToken = false;

  final _authService = AuthService();
  final _soundService = SoundService();
  final _progressService = getIt<ProgressService>();
  final _subjectUsageService = getIt<SubjectUsageService>();
  final _keyboardFocusNode = FocusNode();

  VideoPlayerController? _videoController;
  final AudioPlayer _audioPlayer = AudioPlayer();

  late String _languageCode;

  @override
  void initState() {
    super.initState();
    _languageCode = getIt<TestingLanguageService>().currentLanguageCode.value;
    if (!kIsWeb) windowManager.setResizable(true);

    final isPremium = getIt<SubscriptionService>().isPremium;
    _isAutoPlay =
        isPremium && (_authService.currentUser?.autoPlayEnabled ?? false);
    _isMediaAutoPlayMuted =
        _authService.currentUser?.mediaAutoPlayMuted ?? false;
    _learnAutoplayDelaySeconds =
        _authService.currentUser?.learnAutoplayDelaySeconds ?? 3;

    _sessionQueue = List.from(widget.sessionCards)..shuffle();
    _totalInSession = _sessionQueue.length;
    _pageController = PageController(initialPage: 0);

    _audioPlayer.onPlayerComplete.listen((_) {
      if (_autoPlayAudioToken == _mediaSetupToken) {
        _autoPlayAudioToken = -1;
        _markAutoPlayPlaybackDone(_mediaSetupToken);
      }
    });

    if (_totalInSession > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupMedia();
        _recordCurrentCardProgress();
      });
    }
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_canGoNext && !_isAdvancing) {
        _handleNext();
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _handleBack();
    }
  }

  Future<void> _recordCurrentCardProgress() async {
    if (_recordedCardIds.contains(_currentCard.id)) return;

    _recordedCardIds.add(_currentCard.id);
    setState(() {
      _completedInSession = _recordedCardIds.length;
    });

    await _progressService.recordLearnProgress(
      cardId: _currentCard.id,
      subjectId: _currentCard.subjectId,
    );
  }

  void _setupMedia() {
    final token = ++_mediaSetupToken;
    _autoNextTimer?.cancel();
    _cooldownTimer?.cancel();
    _autoPlayAudioToken = -1;
    _isAutoPlayWaiting = false;
    _autoPlayVisualReady = false;
    _autoPlayPlaybackDone = false;
    _autoPlayScheduledForToken = false;
    setState(() {
      _canGoNext = false;
      _isAdvancing = false;
    });

    if (_recordedCardIds.contains(_currentCard.id)) {
      setState(() => _canGoNext = true);
    } else {
      _cooldownTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _canGoNext = true);
      });
    }

    final lang = _languageCode.toLowerCase();
    final images = _currentCard.getImageUrls(lang);
    final videoUrl = _currentCard.getVideoUrl(lang);

    _videoController?.dispose();
    _videoController = null;

    setState(() {
      _hasVideo = false;
    });

    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoController!.initialize().then((_) {
        if (mounted && token == _mediaSetupToken) {
          setState(() {
            _hasVideo = true;
          });
          _markAutoPlayVisualReady(token);
          if (!_isMediaAutoPlayMuted) {
            _videoController!.play();
          } else {
            _markAutoPlayPlaybackDone(token);
          }
          _videoController!.addListener(_videoListener);
        }
      });
    } else {
      final hasDisplayText =
          _currentCard.getDisplayText(lang).trim().isNotEmpty;
      if (images.isNotEmpty) {
        unawaited(_waitForVisualReady(images.first, token));
      } else if (_currentCard.isSpecialRenderer ||
          _currentCard.isCountingRenderer ||
          _currentCard.isColors ||
          hasDisplayText) {
        _markAutoPlayVisualReadyOnNextFrame(token);
      } else {
        _markAutoPlayVisualReady(token);
      }
    }

    _playInitialMedia(token);
  }

  void _videoListener() {
    if (_videoController == null) return;
    if (_videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.isInitialized) {
      _videoController!.removeListener(_videoListener);
      _markAutoPlayPlaybackDone(_mediaSetupToken);
    }
  }

  Future<void> _playInitialMedia(int token) async {
    await _audioPlayer.stop();
    final lang = _languageCode.toLowerCase();
    final audioUrl = _currentCard.getAudioUrl(lang);
    final videoUrl = _currentCard.getVideoUrl(lang);

    print(
      'LearnPage: playInitialMedia. audio: $audioUrl, video: $videoUrl, showingVideo: $_hasVideo',
    );

    if (videoUrl != null && videoUrl.isNotEmpty) {
      if (_isMediaAutoPlayMuted) {
        _markAutoPlayPlaybackDone(token);
      }
    } else if (audioUrl != null && audioUrl.isNotEmpty) {
      if (!_isMediaAutoPlayMuted) {
        _autoPlayAudioToken = token;
        try {
          await _audioPlayer.play(UrlSource(audioUrl));
        } catch (_) {
          if (_autoPlayAudioToken == token) {
            _autoPlayAudioToken = -1;
            _markAutoPlayPlaybackDone(token);
          }
        }
      } else {
        _markAutoPlayPlaybackDone(token);
      }
    } else {
      _markAutoPlayPlaybackDone(token);
    }
  }

  Future<void> _waitForVisualReady(String imageUrl, int token) async {
    try {
      if (!imageUrl.toLowerCase().endsWith('.svg')) {
        await precacheImage(NetworkImage(imageUrl), context);
      } else {
        await WidgetsBinding.instance.endOfFrame;
      }
    } catch (_) {
      // Fall through and mark ready once we can show the fallback.
    }
    _markAutoPlayVisualReadyOnNextFrame(token);
  }

  void _markAutoPlayVisualReadyOnNextFrame(int token) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAutoPlayVisualReady(token);
    });
  }

  void _markAutoPlayVisualReady(int token) {
    if (!mounted || token != _mediaSetupToken || _autoPlayVisualReady) return;
    _autoPlayVisualReady = true;
    _maybeScheduleAutoPlay(token);
  }

  void _markAutoPlayPlaybackDone(int token) {
    if (!mounted || token != _mediaSetupToken || _autoPlayPlaybackDone) return;
    _autoPlayPlaybackDone = true;
    _maybeScheduleAutoPlay(token);
  }

  void _maybeScheduleAutoPlay(int token, {bool restart = false}) {
    if (!mounted || token != _mediaSetupToken || !_isAutoPlay) return;
    if (!_autoPlayVisualReady || !_autoPlayPlaybackDone) return;
    if (_autoPlayScheduledForToken && !restart) return;
    _autoPlayScheduledForToken = true;
    _scheduleAutoNext(restart: restart);
  }

  void _scheduleAutoNext({bool restart = false}) {
    if (!_isAutoPlay) return;
    if (_isAutoPlayWaiting && !restart) return;
    if (restart) {
      _autoNextTimer?.cancel();
      setState(() => _isAutoPlayWaiting = false);
    }
    print(
      'LearnPage: Scheduling auto-next with delay $_learnAutoplayDelaySeconds s',
    );
    setState(() => _isAutoPlayWaiting = true);
    final delay = Duration(seconds: _learnAutoplayDelaySeconds);
    _autoNextTimer?.cancel();
    _autoNextTimer = Timer(delay, () {
      print(
        'LearnPage: Auto-next timer fired. mounted: $mounted, waiting: $_isAutoPlayWaiting',
      );
      if (mounted && _isAutoPlay && _isAutoPlayWaiting) _handleNext();
    });
  }

  Future<void> _setLearnAutoplayDelay(int seconds) async {
    if (_learnAutoplayDelaySeconds == seconds) return;
    setState(() => _learnAutoplayDelaySeconds = seconds);
    await _authService.updateLearnAutoplayDelay(seconds);

    if (mounted && _isAutoPlay && _isAutoPlayWaiting) {
      _scheduleAutoNext(restart: true);
    }
  }

  void _toggleAutoPlay() {
    final sub = getIt<SubscriptionService>();
    if (!sub.isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PremiumUpgradePage()),
      );
      return;
    }

    final newVal = !_isAutoPlay;
    _authService.updateAutoPlayPreference(newVal);
    setState(() {
      _isAutoPlay = newVal;
      if (_isAutoPlay) {
        _maybeScheduleAutoPlay(_mediaSetupToken, restart: true);
      } else {
        _autoNextTimer?.cancel();
        _isAutoPlayWaiting = false;
      }
    });
  }

  Future<void> _toggleMediaAutoPlayMuted() async {
    final newValue = !_isMediaAutoPlayMuted;
    setState(() => _isMediaAutoPlayMuted = newValue);
    await _authService.updateMediaAutoPlayMuted(newValue);

    if (newValue) {
      await _audioPlayer.stop();
      await _videoController?.pause();
    }
  }

  Future<void> _showAutoplayDelayMenu(Offset globalPosition) async {
    final sub = getIt<SubscriptionService>();
    if (!sub.isPremium) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const PremiumUpgradePage()),
      );
      return;
    }

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(globalPosition, globalPosition),
        Offset.zero & overlay.size,
      ),
      items:
          _autoPlayDelayOptions
              .map(
                (seconds) => PopupMenuItem<int>(
                  value: seconds,
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color:
                            seconds == _learnAutoplayDelaySeconds
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey[700],
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text('${seconds}s')),
                      if (seconds == _learnAutoplayDelaySeconds)
                        Icon(
                          Icons.check,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  ),
                ),
              )
              .toList(),
    );

    if (selected != null) {
      await _setLearnAutoplayDelay(selected);
    }
  }

  Widget _buildAutoplayControl() {
    final isPremium = getIt<SubscriptionService>().isPremium;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color:
            _isAutoPlay
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color:
              _isAutoPlay
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleAutoPlay,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    _isAutoPlay ? Icons.pause_circle : Icons.play_circle,
                    color: _isAutoPlay ? Colors.white : Colors.white70,
                    size: 22,
                  ),
                  if (!isPremium)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(1.5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          color: Colors.amber,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 16,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown:
                (details) => _showAutoplayDelayMenu(details.globalPosition),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 8, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_learnAutoplayDelaySeconds}s',
                    style: TextStyle(
                      color: _isAutoPlay ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    color: _isAutoPlay ? Colors.white70 : Colors.white54,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaMuteControl() {
    return IconButton(
      tooltip: _isMediaAutoPlayMuted ? 'Unmute auto-play' : 'Mute auto-play',
      icon: Icon(
        _isMediaAutoPlayMuted ? Icons.volume_off : Icons.volume_up,
        color: Colors.white,
      ),
      onPressed: _toggleMediaAutoPlayMuted,
    );
  }

  Future<void> _handleNext() async {
    if (!_canGoNext || _isAdvancing) return;

    if (_currentIndex < _sessionQueue.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishSession();
    }
  }

  void _handleBack() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishSession() async {
    if (_isSessionFinished) return;
    print('LearnPage: Finishing session');
    setState(() => _isAdvancing = true);
    _autoNextTimer?.cancel();
    _cooldownTimer?.cancel();
    setState(() => _isAutoPlayWaiting = false);

    _audioPlayer.stop();
    _videoController?.pause();
    _autoPlayAudioToken = -1;

    _progressService.awardSubjectCompletionBonus(_totalInSession);
    unawaited(
      _subjectUsageService.recordSessionComplete(
        subjectIds: widget.sessionCards.map((sc) => sc.card.subjectId),
        mode: 'learn',
      ),
    );
    _soundService.playCompleted();
    if (mounted) {
      setState(() {
        _isSessionFinished = true;
        _isAdvancing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = _languageCode.toLowerCase();
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

        if (_isSessionFinished) {
          return SessionCompletionWindow(
            subjectTitle: _subject.getName(_languageCode),
            headerColor: headerColor,
            actionLabel: context.t('back_to_subjects'),
            onBackPressed: () => Navigator.pop(context, true),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.school_outlined, size: 64, color: headerColor),
                const SizedBox(height: 20),
                Text(
                  context.t('learning_session_complete_description'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

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
                _buildAutoplayControl(),
                if (!kIsWeb) const WindowControls(color: Colors.white),
              ],
            ),
            body: Stack(
              children: [
                Column(
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
                            if (answers.isEmpty)
                              return [const SizedBox.shrink()];

                            return [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children:
                                    answers
                                        .map(
                                          (ans) => Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            child: Text(
                                              CardModel.capitalizeFirst(ans),
                                              style: TextStyle(
                                                fontSize:
                                                    answers.length > 1
                                                        ? 24
                                                        : 32,
                                                color: headerColor,
                                                fontWeight: FontWeight.bold,
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
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _sessionQueue.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                            _setupMedia();
                            _recordCurrentCardProgress();
                          });
                        },
                        itemBuilder: (context, index) {
                          final itemCard = _sessionQueue[index].card;
                          final isCurrent = index == _currentIndex;
                          final audioUrl = itemCard.getAudioUrl(lang) ?? '';
                          final hasAudioUrl = audioUrl.isNotEmpty;
                          return Center(
                            child: CardMediaContent(
                              card: itemCard,
                              subject: _sessionQueue[index].subject,
                              languageCode: lang,
                              headerColor: headerColor,
                              isMobile: MediaQuery.sizeOf(context).width < 600,
                              videoController:
                                  isCurrent ? _videoController : null,
                              hasVideo: itemCard.hasVideoUrl(lang),
                              images: itemCard.getImageUrls(lang),
                              onPlayAudio:
                                  hasAudioUrl
                                      ? () =>
                                          _audioPlayer.play(UrlSource(audioUrl))
                                      : null,
                              hasAudio: hasAudioUrl,
                              hideAudioIcon: false,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                // Side Navigation Controls
                if (_currentIndex > 0)
                  Positioned(
                    left: 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white,
                          size: 40,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.4),
                          padding: const EdgeInsets.all(12),
                        ),
                        onPressed: _handleBack,
                      ),
                    ),
                  ),
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 120),
                      opacity: (_canGoNext && !_isAdvancing) ? 1.0 : 0.45,
                      child: IconButton(
                        icon: const Icon(
                          Icons.chevron_right,
                          color: Colors.white,
                          size: 40,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.4),
                          padding: const EdgeInsets.all(12),
                        ),
                        onPressed:
                            (_canGoNext && !_isAdvancing) ? _handleNext : null,
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
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}
