import 'dart:async';
import 'package:flutter/material.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/sound_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/utils/session_bucket_sampler.dart';
import 'package:aliolo/core/widgets/card_renderer.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/aliolo_image.dart';
import 'package:aliolo/core/widgets/counting_grid.dart';
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
  int _currentImageIndex = 0;
  bool _showingVideo = false;

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

  late final Player player = Player();
  late final VideoController controller = VideoController(player);

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

    _playerSubscription = player.stream.completed.listen((completed) {
      if (completed) {
        print('LearnPage: Player completed. autoPlay: $_isAutoPlay, waiting: $_isAutoPlayWaiting');
        if (_isAutoPlay && !_isAutoPlayWaiting) {
          _scheduleAutoNext();
        }
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
    final video = _currentCard.getVideoUrl(lang);

      setState(() {
        _currentImages = images;
        _currentImageIndex = 0;
        _showingVideo = video?.isNotEmpty ?? false;
      });

    _playInitialMedia();
  }

  Future<void> _playInitialMedia() async {
    await player.stop();
    final lang = _languageCode.toLowerCase();
    final audioUrl = _currentCard.getAudioUrl(lang);
    final videoUrl = _currentCard.getVideoUrl(lang);

    print('LearnPage: playInitialMedia. audio: $audioUrl, video: $videoUrl, showingVideo: $_showingVideo');

    bool hasMedia = false;
    if (_showingVideo && videoUrl != null && videoUrl.isNotEmpty) {
      await player.open(Media(videoUrl));
      player.play();
      hasMedia = true;
    } else if (audioUrl != null && audioUrl.isNotEmpty) {
      await player.open(Media(audioUrl));
      player.play();
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
    player.stop();

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

                        final hasAudio = currentAudioUrl?.isNotEmpty ?? false;

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
                          if (hasAudio)
                            IconButton(
                              icon: const Icon(Icons.volume_up),
                              color: headerColor,
                              tooltip: context.t('play_audio'),
                              onPressed: () async {
                                final url = currentAudioUrl;
                                if (url != null && url.isNotEmpty) {
                                  await player.open(Media(url));
                                  player.play();
                                }
                              },
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
                        color: Theme.of(context).cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: headerColor.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Container(
                          color: headerColor.withValues(alpha: 0.05),
                          child: _currentCard.isSpecialRenderer
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: CardRenderer(
                                      card: _currentCard,
                                      subject: _subject,
                                      languageCode: lang,
                                      fallbackColor: headerColor,
                                      fit: BoxFit.contain,
                                      textFontSize: 120,
                                    ),
                                  ),
                                )
                              : Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_showingVideo)
                                      Video(controller: controller)
                                    else if (_currentCard.isCountingRenderer)
                                      CountingGrid(
                                        count: _currentCard.numericalAnswer,
                                        iconSize: 60,
                                      )
                                    else if (_currentCard.isColors)
                                      CardRenderer(
                                        card: _currentCard,
                                        subject: _subject,
                                        languageCode: lang,
                                        fallbackColor: headerColor,
                                        fit: BoxFit.contain,
                                        textFontSize: 120,
                                      )
                                    else if (_currentImages.isNotEmpty)
                                      AlioloImage(
                                        imageUrl:
                                            _currentImages[_currentImageIndex],
                                        fit: BoxFit.contain,
                                        backgroundColor: headerColor.withValues(
                                          alpha: 0.05,
                                        ),
                                      )
                                    else if (_currentCard.isSpecialRenderer)
                                      CardRenderer(
                                        card: _currentCard,
                                        subject: _subject,
                                        languageCode: lang,
                                        fallbackColor: headerColor,
                                        fit: BoxFit.contain,
                                        textFontSize: 120,
                                      )
                                    else if (_currentCard
                                            .getDisplayText(lang)
                                            .trim()
                                            .isNotEmpty)
                                      Center(
                                        child: Text(
                                          _currentCard.getDisplayText(lang),
                                          style: const TextStyle(
                                            fontSize: 120,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
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
                                          onPressed: () => setState(
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
                                          onPressed: () => setState(
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
