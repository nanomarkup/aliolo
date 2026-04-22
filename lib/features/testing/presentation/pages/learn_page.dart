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
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/utils/session_bucket_sampler.dart';
import 'package:aliolo/core/widgets/card_media_content.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
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
  static const List<int> _autoPlayDelayOptions = <int>[1, 2, 3, 4, 5];

  late SubjectCard _currentSubjectCard;
  CardModel get _currentCard => _currentSubjectCard.card;
  SubjectModel get _subject => _currentSubjectCard.subject;

  // Media State
  List<String> _currentImages = [];
  int _currentMediaIndex = 0;
  bool _hasVideo = false;

  // Session State
  List<SubjectCard> _sessionQueue = [];
  int _completedInSession = 0;
  int _totalInSession = 0;

  bool _isAutoPlay = false;
  bool _isAutoPlayWaiting = false;
  bool _canGoNext = false;
  bool _isAdvancing = false;
  int _learnAutoplayDelaySeconds = 3;
  Timer? _autoNextTimer;
  Timer? _cooldownTimer;
  StreamSubscription? _playerSubscription;

  final _authService = AuthService();
  final _soundService = SoundService();
  final _progressService = getIt<ProgressService>();
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
    _learnAutoplayDelaySeconds =
        _authService.currentUser?.learnAutoplayDelaySeconds ?? 3;

    _sessionQueue = List.from(widget.sessionCards);

    _totalInSession = _sessionQueue.length;

    if (_sessionQueue.isNotEmpty) {
      final firstCard = SessionBucketSampler.takeRandom(_sessionQueue);
      if (firstCard != null) {
        _currentSubjectCard = firstCard;
        _completedInSession = 1;
      }
    }

    _audioPlayer.onPlayerComplete.listen((_) {
      if (_isAutoPlay && !_isAutoPlayWaiting) {
        _scheduleAutoNext();
      }
    });

    if (_completedInSession > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupMedia();
      });
    }
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (_canGoNext && !_isAdvancing) {
        _nextCard();
      }
    }
  }

  void _setupMedia() {
    _autoNextTimer?.cancel();
    _cooldownTimer?.cancel();
    _isAutoPlayWaiting = false;
    setState(() {
      _canGoNext = false;
      _isAdvancing = false;
    });

    _cooldownTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _canGoNext = true);
    });

    final lang = _languageCode.toLowerCase();
    final images = _currentCard.getImageUrls(lang);
    final videoUrl = _currentCard.getVideoUrl(lang);

    _videoController?.dispose();
    _videoController = null;

    if (videoUrl != null && videoUrl.isNotEmpty) {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      _videoController!.initialize().then((_) {
        if (mounted) {
          setState(() {
            _hasVideo = true;
          });
          _videoController!.play();
          _videoController!.addListener(_videoListener);
        }
      });
    } else {
      setState(() {
        _hasVideo = false;
        _currentImages = images;
        _currentMediaIndex = 0;
      });
    }

    _playInitialMedia();
  }

  void _videoListener() {
    if (_videoController == null) return;
    if (_videoController!.value.position >= _videoController!.value.duration &&
        _videoController!.value.isInitialized) {
      _videoController!.removeListener(_videoListener);
      if (_isAutoPlay && !_isAutoPlayWaiting) {
        _scheduleAutoNext();
      }
    }
  }

  Future<void> _playInitialMedia() async {
    await _audioPlayer.stop();
    final lang = _languageCode.toLowerCase();
    final audioUrl = _currentCard.getAudioUrl(lang);
    final videoUrl = _currentCard.getVideoUrl(lang);

    print('LearnPage: playInitialMedia. audio: $audioUrl, video: $videoUrl, showingVideo: $_hasVideo');

    bool hasMedia = false;
    if (videoUrl != null && videoUrl.isNotEmpty) {
      // Video handled in _setupMedia
      hasMedia = true;
    } else if (audioUrl != null && audioUrl.isNotEmpty) {
      await _audioPlayer.play(UrlSource(audioUrl));
      hasMedia = true;
    }

    if (_isAutoPlay && !hasMedia) {
      _scheduleAutoNext();
    }
  }

  void _scheduleAutoNext({bool restart = false}) {
    if (!_isAutoPlay) return;
    if (_isAutoPlayWaiting && !restart) return;
    if (restart) {
      _autoNextTimer?.cancel();
      setState(() => _isAutoPlayWaiting = false);
    }
    print('LearnPage: Scheduling auto-next with delay $_learnAutoplayDelaySeconds s');
    setState(() => _isAutoPlayWaiting = true);
    final delay = Duration(seconds: _learnAutoplayDelaySeconds);
    _autoNextTimer?.cancel();
    _autoNextTimer = Timer(delay, () {
      print('LearnPage: Auto-next timer fired. mounted: $mounted, waiting: $_isAutoPlayWaiting');
      if (mounted && _isAutoPlay && _isAutoPlayWaiting) _nextCard();
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
        _scheduleAutoNext(restart: true);
      } else {
        _autoNextTimer?.cancel();
        _isAutoPlayWaiting = false;
      }
    });
  }

  Future<void> _showAutoplayDelayMenu(Offset globalPosition) async {
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleAutoPlay,
      onLongPressStart: (details) => _showAutoplayDelayMenu(details.globalPosition),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              _isAutoPlay ? Icons.pause_circle : Icons.play_circle,
              color: Colors.white,
            ),
            if (!isPremium)
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
      ),
    );
  }

  Future<void> _nextCard() async {
    if (!_canGoNext || _isAdvancing) return;
    print('LearnPage: Moving to next card');
    setState(() => _isAdvancing = true);
    _autoNextTimer?.cancel();
    _cooldownTimer?.cancel();
    setState(() => _isAutoPlayWaiting = false);
    
    _audioPlayer.stop();
    _videoController?.pause();

    await _progressService.recordLearnProgress(
      cardId: _currentCard.id,
      subjectId: _currentCard.subjectId,
    );

    final nextCard = SessionBucketSampler.takeRandom(_sessionQueue);
    if (nextCard != null) {
      _completedInSession++;
      setState(() => _currentSubjectCard = nextCard);
      _setupMedia();
      return;
    }

    _progressService.awardSubjectCompletionBonus(_totalInSession);
    _soundService.playCompleted();
    _showCompletionDialog();
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

  @override
  Widget build(BuildContext context) {
    final lang = _languageCode.toLowerCase();
    final currentAudioUrl = _currentCard.getAudioUrl(lang);
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

        final hasMeaningfulDisplayText = _currentCard.hasMeaningfulDisplayText(lang);
        final displayText = hasMeaningfulDisplayText ? _currentCard.getDisplayText(lang).trim() : '';
        final hasVisual = _currentCard.isSpecialRenderer ||
                          _currentCard.isCountingRenderer ||
                          _currentCard.isColors ||
                          _hasVideo ||
                          _currentImages.isNotEmpty ||
                          displayText.isNotEmpty;
        
        final showAudioInHeader = !hasVisual && (currentAudioUrl?.isNotEmpty ?? false);

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
                _buildAutoplayControl(),
                if (!kIsWeb) const WindowControls(color: Colors.white),
              ],
            ),
            floatingActionButton:
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: (_canGoNext && !_isAdvancing) ? 1.0 : 0.45,
                  child: FloatingActionButton.extended(
                    onPressed:
                        (_canGoNext && !_isAdvancing) ? _nextCard : null,
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

                        if (showAudioInHeader) {
                          return [
                            IconButton(
                              icon: const Icon(Icons.volume_up),
                              color: headerColor,
                              tooltip: context.t('play_audio'),
                              onPressed: () async {
                                if (currentAudioUrl != null && currentAudioUrl.isNotEmpty) {
                                  await _audioPlayer.play(UrlSource(currentAudioUrl));
                                }
                              },
                            )
                          ];
                        }

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
                                                answers.length > 1 ? 24 : 32,
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
                  child: CardMediaContent(
                    card: _currentCard,
                    subject: _subject,
                    languageCode: lang,
                    headerColor: headerColor,
                    isMobile: false, // LearnPage uses desktop-style layout sizing
                    videoController: _videoController,
                    hasVideo: _hasVideo,
                    images: _currentImages,
                    mediaIndex: _currentMediaIndex,
                    onMediaIndexChanged: (index) {
                      if (mounted) {
                        setState(() => _currentMediaIndex = index);
                      }
                    },
                    onPlayAudio: currentAudioUrl?.isNotEmpty == true ? () async {
                      await _audioPlayer.play(UrlSource(currentAudioUrl!));
                    } : null,
                    hasAudio: showAudioInHeader ? false : (currentAudioUrl?.isNotEmpty == true),
                    hideAudioIcon: showAudioInHeader,
                    headerText: showAudioInHeader ? null : (_currentCard.getAnswerList(lang).isNotEmpty 
                        ? _currentCard.getAnswerList(lang).first 
                        : null),
                    centerTextOverride: showAudioInHeader && _currentCard.getAnswerList(lang).isNotEmpty 
                        ? _currentCard.getAnswerList(lang).first 
                        : null,
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
