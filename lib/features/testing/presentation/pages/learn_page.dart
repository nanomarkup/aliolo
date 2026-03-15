import 'dart:async';
import 'package:flutter/material.dart';
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
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/widgets/window_controls.dart';

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
    if (!kIsWeb) windowManager.setResizable(true);
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

    // Filter cards that have at least an answer in target lang, en, or global
    final lang = widget.languageCode.toLowerCase();
    final langFiltered =
        allCards.where((c) {
          return c.getAnswer(lang).isNotEmpty || c.getAnswer('en').isNotEmpty;
        }).toList();

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

  void _nextCard() {
    _autoNextTimer?.cancel();
    setState(() => _isAutoPlayWaiting = false);
    player.stop();

    _progressService.recordLearnProgress(
      cardId: _currentCard.id,
      subjectId: _currentCard.subjectId,
    );

    if (_sessionQueue.isNotEmpty) {
      _sessionQueue.removeAt(0);
      _completedInSession++;
    }

    if (_sessionQueue.isNotEmpty) {
      setState(() => _currentCard = _sessionQueue.first);
      _setupMedia();
    } else {
      _progressService.awardSubjectCompletionBonus(_totalInSession);
      _soundService.playCompleted();
      _showCompletionDialog();
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(context.t('session_complete')),
            content: const Text(
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
                          Text(
                            e.value.answer ?? '-',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
    bool isLeft = _authService.currentUser?.sidebarLeft ?? false;
    final lang = widget.languageCode.toLowerCase();
    Color headerColor = Colors.orange;
    if (_subject != null) {
      headerColor =
          pillars
              .firstWhere(
                (p) => p.id == _subject!.pillarId,
                orElse: () => pillars.first,
              )
              .getColor();
    }

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        double progressValue =
            _totalInSession > 0 ? _completedInSession / _totalInSession : 0.0;

        Widget sidebar = Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              LinearProgressIndicator(
                value: progressValue,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                color: headerColor,
              ),
              const SizedBox(height: 48),
              Text(
                _currentCard.getPrompt(lang),
                style: TextStyle(fontSize: 24, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                _currentCard.getAnswer(lang),
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: headerColor,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (_currentCard.getAudioUrl(lang) != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final url = _currentCard.getAudioUrl(lang);
                      if (url != null) {
                        await player.open(Media(url));
                        player.play();
                      }
                    },
                    icon: const Icon(Icons.volume_up),
                    label: const Text('Play Audio'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _nextCard,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(context.t('next')),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(70),
                        backgroundColor: headerColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton.filledTonal(
                    onPressed: () {
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
                    icon: Icon(
                      _isAutoPlay ? Icons.pause_circle : Icons.play_circle,
                      size: 32,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(70, 70),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

        Widget mainContent = Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Card(
                  elevation: 8,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_showingVideo)
                        Video(controller: controller)
                      else if (_currentImages.isNotEmpty)
                        Image.network(
                          _currentImages[_currentImageIndex],
                          fit: BoxFit.contain,
                        )
                      else
                        const Icon(
                          Icons.image_not_supported,
                          size: 100,
                          color: Colors.grey,
                        ),
                      if (!_showingVideo && _currentImages.length > 1) ...[
                        Positioned(
                          left: 10,
                          top: 0,
                          bottom: 0,
                          child: IconButton(
                            icon: const Icon(
                              Icons.chevron_left,
                              color: Colors.white,
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
                              color: Colors.white,
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
        );

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text(_translatedSubjectName),
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
          body: Row(
            children: isLeft ? [sidebar, mainContent] : [mainContent, sidebar],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _autoNextTimer?.cancel();
    _playerSubscription?.cancel();
    player.dispose();
    super.dispose();
  }
}
