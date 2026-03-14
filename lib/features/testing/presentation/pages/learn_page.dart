import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
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
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/core/utils/logger.dart';

class LearnPage extends StatefulWidget {
  final CardModel card;
  final String languageCode;

  const LearnPage({super.key, required this.card, required this.languageCode});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  late CardModel _currentCard;
  SubjectModel? _subject;
  String _translatedSubjectName = '';

  // Media State
  List<String> _currentImages = [];
  int _currentImageIndex = 0;
  bool _showingVideo = false;

  // Session State
  List<CardModel> _sessionQueue = [];
  int _completedInSession = 0;
  int _totalInSession = 0;

  bool _isAutoPlay = false;
  bool _isAutoPlayWaiting = false;
  Timer? _autoNextTimer;
  StreamSubscription? _playerSubscription;

  final _authService = AuthService();
  final _soundService = SoundService();
  final _progressService = getIt<ProgressService>();

  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    _isAutoPlay = _authService.currentUser?.autoPlayEnabled ?? false;
    _currentCard = widget.card;

    _playerSubscription = player.stream.completed.listen((completed) {
      if (completed && _isAutoPlay && !_isAutoPlayWaiting) {
        _scheduleAutoNext(afterMedia: true);
      }
    });

    _initSession();
  }

  Future<void> _initSession() async {
    final user = _authService.currentUser;
    if (user == null) return;

    _subject = await CardService().getSubjectById(_currentCard.subjectId);
    if (_subject != null) {
      _translatedSubjectName = _subject!.getName(widget.languageCode);
    }

    final allCards = await CardService().getCardsBySubject(
      _currentCard.subjectId,
    );
    if (allCards.isEmpty) return;

    final lang = widget.languageCode.toLowerCase();
    final langFiltered =
        allCards
            .where(
              (c) => c.answers.containsKey(lang) || c.answers.containsKey('en'),
            )
            .toList();
    langFiltered.shuffle();

    final size = user.learnSessionSize;
    _sessionQueue = langFiltered.take(size).toList();

    if (_sessionQueue.isNotEmpty) {
      setState(() {
        _totalInSession = _sessionQueue.length;
        _currentCard = _sessionQueue.first;
        _setupMedia();
      });
    }
  }

  void _setupMedia() {
    _autoNextTimer?.cancel();
    _isAutoPlayWaiting = false;

    setState(() {
      _currentImages = [
        if (_currentCard.imageUrl != null && _currentCard.imageUrl!.isNotEmpty)
          _currentCard.imageUrl!,
        ..._currentCard.imageUrls.where((u) => u != _currentCard.imageUrl),
      ];
      _currentImageIndex = 0;

      _showingVideo =
          _currentImages.isEmpty &&
          (_currentCard.videoUrl?.isNotEmpty ?? false);
    });

    _playInitialMedia();
  }

  Future<void> _playInitialMedia() async {
    await player.stop();

    final lang = widget.languageCode.toLowerCase();
    final audioUrl =
        _currentCard.audioUrls[lang] ?? _currentCard.audioUrls['en'];

    bool hasMedia = false;
    if (_showingVideo && _currentCard.videoUrl != null) {
      await player.open(Media(_currentCard.videoUrl!));
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

    // If media just finished, shorter delay. If no media, longer delay to read.
    final delay =
        afterMedia ? const Duration(seconds: 2) : const Duration(seconds: 4);

    _autoNextTimer?.cancel();
    _autoNextTimer = Timer(delay, () {
      if (mounted && _isAutoPlay && _isAutoPlayWaiting) {
        _nextCard();
      }
    });
  }

  void _nextCard() {
    _autoNextTimer?.cancel();
    setState(() => _isAutoPlayWaiting = false);
    player.stop();

    // Record progress for the card just viewed
    _progressService.recordLearnProgress(
      cardId: _currentCard.id,
      subjectId: _currentCard.subjectId,
    );

    if (_sessionQueue.isNotEmpty) {
      _sessionQueue.removeAt(0);
      _completedInSession++;
    }

    if (_sessionQueue.isNotEmpty) {
      setState(() {
        _currentCard = _sessionQueue.first;
      });
      _setupMedia();
    } else {
      _progressService.awardSubjectCompletionBonus(_totalInSession);
      _soundService.playCompleted();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: Text(context.t('session_complete')),
              content: Text(
                'You have finished reviewing all cards in this session.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: Text(context.t('back_to_subjects')),
                ),
              ],
            ),
      );
    }
  }

  String _getDisplayPrompt(CardModel card) {
    final lang = widget.languageCode.toLowerCase();
    return card.prompts[lang] ??
        card.prompts['en'] ??
        card.prompts.values.firstOrNull ??
        '';
  }

  String _getDisplayAnswer(CardModel card) {
    final lang = widget.languageCode.toLowerCase();
    return card.answers[lang] ??
        card.answers['en'] ??
        card.answers.values.firstOrNull ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    bool isLeft = _authService.currentUser?.sidebarLeft ?? false;
    const appBarColor = Colors.white;

    Color headerColor = ThemeService().sessionColorNotifier.value;
    if (_subject != null) {
      final p = pillars.firstWhere(
        (p) => p.id == _subject!.pillarId,
        orElse: () => pillars.first,
      );
      headerColor = p.getColor();
    }

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        double progressValue =
            _totalInSession > 0 ? _completedInSession / _totalInSession : 0.0;

        Widget sidebar = Container(
          width: 400,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(headerColor),
                ),
              ),
              const SizedBox(height: 48),

              Text(
                _getDisplayPrompt(_currentCard),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _getDisplayAnswer(_currentCard),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: headerColor,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              if (_currentCard.audioUrls.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final lang = widget.languageCode.toLowerCase();
                      final url =
                          _currentCard.audioUrls[lang] ??
                          _currentCard.audioUrls['en'];
                      if (url != null) {
                        await player.open(Media(url));
                        player.play();
                      }
                    },
                    icon: const Icon(Icons.volume_up, size: 32),
                    label: const Text(
                      'Play Audio',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: headerColor.withValues(alpha: 0.1),
                      foregroundColor: headerColor,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

              if (_currentCard.videoUrl != null &&
                  _currentCard.videoUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: ElevatedButton.icon(
                    onPressed:
                        () => setState(() {
                          _showingVideo = !_showingVideo;
                          if (_showingVideo) {
                            player.open(Media(_currentCard.videoUrl!));
                            player.play();
                          } else {
                            player.stop();
                          }
                        }),
                    icon: Icon(
                      _showingVideo ? Icons.image : Icons.videocam,
                      size: 32,
                    ),
                    label: Text(
                      _showingVideo ? 'Show Image' : 'Show Video',
                      style: const TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: headerColor.withValues(alpha: 0.1),
                      foregroundColor: headerColor,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextCard,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        context.t('next'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(70),
                        backgroundColor: headerColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      color:
                          _isAutoPlay
                              ? headerColor.withValues(alpha: 0.2)
                              : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _isAutoPlay ? headerColor : Colors.grey[400]!,
                        width: 2,
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isAutoPlay
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_fill,
                        size: 32,
                        color: _isAutoPlay ? headerColor : Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _isAutoPlay = !_isAutoPlay;
                          if (_isAutoPlay && !_isAutoPlayWaiting) {
                            // Check if already finished or no media
                            if (player.state.completed) {
                              _scheduleAutoNext(afterMedia: true);
                            } else {
                              // Will be handled by stream listener or _playInitialMedia
                            }
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        Widget mainContent = Expanded(
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Card(
                      elevation: 10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child:
                                _showingVideo && _currentCard.videoUrl != null
                                    ? Video(controller: controller)
                                    : (_currentImages.isNotEmpty
                                        ? Image.network(
                                          _currentImages[_currentImageIndex],
                                          fit: BoxFit.contain,
                                        )
                                        : const Icon(
                                          Icons.image_not_supported,
                                          size: 100,
                                          color: Colors.grey,
                                        )),
                          ),
                          if (!_showingVideo && _currentImages.length > 1) ...[
                            Positioned(
                              left: 20,
                              child: CircleAvatar(
                                backgroundColor: Colors.black45,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    color: Colors.white,
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
                            ),
                            Positioned(
                              right: 20,
                              child: CircleAvatar(
                                backgroundColor: Colors.black45,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.chevron_right,
                                    color: Colors.white,
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
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: DragToMoveArea(
              child: SizedBox(
                width: double.infinity,
                child: Text(_translatedSubjectName),
              ),
            ),
            backgroundColor: headerColor,
            foregroundColor: appBarColor,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: appBarColor),
                onPressed: () => Navigator.pop(context),
              ),
              const WindowControls(color: appBarColor, iconSize: 24),
            ],
          ),
          body: Row(
            children:
                isLeft
                    ? [sidebar, const VerticalDivider(width: 1), mainContent]
                    : [mainContent, const VerticalDivider(width: 1), sidebar],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _playerSubscription?.cancel();
    player.stop();
    player.dispose();
    super.dispose();
  }
}
