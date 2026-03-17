import 'dart:math';
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
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/math_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';

class TestPage extends StatefulWidget {
  final CardModel card;
  final String languageCode;

  const TestPage({super.key, required this.card, required this.languageCode});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late CardModel _currentCard;
  SubjectModel? _subject;
  String _translatedSubjectName = '';

  // MCQ State
  List<String> _options = [];
  int _selectedIndex = -1;
  bool _isAnswered = false;
  bool _isCorrect = false;
  String _correctAnswerText = '';

  // Media State
  List<String> _currentImages = [];
  int _currentImageIndex = 0;
  bool _showingVideo = false;

  // Session State
  List<CardModel> _sessionQueue = [];
  int _completedInSession = 0;
  int _totalInSession = 0;
  int _sessionCorrect = 0;
  int _sessionWrong = 0;

  bool _isAutoPlay = false;
  bool _isAutoPlayWaiting = false;

  final _authService = AuthService();
  final _soundService = SoundService();
  final _progressService = ProgressService();

  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) windowManager.setResizable(true);
    _isAutoPlay = _authService.currentUser?.autoPlayEnabled ?? false;
    _currentCard = widget.card;
    _initSession();
  }

  Future<void> _initSession() async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (_currentCard.subjectId != 'Math') {
      _subject = await CardService().getSubjectById(_currentCard.subjectId);
      if (_subject != null) {
        _translatedSubjectName = _subject!.getName(widget.languageCode);
      }
    } else {
      _translatedSubjectName = 'Math';
    }

    // Special handling for Math virtual cards (keep as is for now)
    if (_currentCard.subjectId == 'Math') {
      final int mathLevel = widget.card.level;
      final List<CardModel> sessionCards = List.generate(user.testSessionSize, (
        i,
      ) {
        final problem = MathService().generateProblem(mathLevel);
        return MathService().createVirtualCard(problem, mathLevel);
      });
      setState(() {
        _sessionQueue = sessionCards;
        _totalInSession = _sessionQueue.length;
        _currentCard = _sessionQueue.first;
        _setupMCQ();
      });
      return;
    }

    final allCards = await CardService().getCardsBySubject(
      _currentCard.subjectId,
    );
    if (allCards.isEmpty) return;

    final lang = widget.languageCode.toLowerCase();
    final langFiltered =
        allCards.where((c) {
          return c.getAnswer(lang).isNotEmpty || c.getAnswer('en').isNotEmpty;
        }).toList();

    langFiltered.shuffle();
    _sessionQueue = langFiltered.take(user.testSessionSize).toList();

    if (_sessionQueue.isNotEmpty) {
      setState(() {
        _totalInSession = _sessionQueue.length;
        _currentCard = _sessionQueue.first;
        _setupMCQ();
      });
    }
  }

  String _getDisplayAnswer(CardModel card) {
    final lang = widget.languageCode.toLowerCase();
    String ans = card.getAnswer(lang);
    if (ans.contains(';')) {
      final parts =
          ans
              .split(';')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
      return parts.isNotEmpty ? parts[Random().nextInt(parts.length)] : ans;
    }
    return ans;
  }

  Future<void> _setupMCQ() async {
    _correctAnswerText = _getDisplayAnswer(_currentCard);
    final user = _authService.currentUser;
    final lang = widget.languageCode.toLowerCase();

    List<String> options = [];

    if (_currentCard.subjectId == 'Math') {
      // options from math virtual card logic
    } else {
      final allInSubject = await CardService().getCardsBySubject(
        _currentCard.subjectId,
      );
      final validOptions =
          allInSubject
              .where((c) => c.id != _currentCard.id)
              .map((c) => _getDisplayAnswer(c))
              .where((ans) => ans.isNotEmpty && ans != _correctAnswerText)
              .toSet()
              .toList();

      validOptions.shuffle();
      final optCount = user?.optionsCount ?? 6;
      options = validOptions.take(optCount - 1).toList();
      options.add(_correctAnswerText);
      options.shuffle();
    }

    setState(() {
      _options = options;
      _selectedIndex = -1;
      _isAnswered = false;
      _isCorrect = false;
      _currentImages = _currentCard.getImageUrls(lang);
      _currentImageIndex = 0;
      final video = _currentCard.getVideoUrl(lang);
      _showingVideo = _currentImages.isEmpty && (video?.isNotEmpty ?? false);
    });

    final audio = _currentCard.getAudioUrl(lang);
    if (audio != null) {
      player.open(Media(audio));
      player.play();
    }
  }

  Future<void> _selectOption(int index) async {
    if (_isAnswered) return;
    final correct = _options[index] == _correctAnswerText;
    setState(() {
      _selectedIndex = index;
      _isAnswered = true;
      _isCorrect = correct;
    });

    if (correct) {
      _sessionCorrect++;
      _soundService.playCorrect();
      await _progressService.recordProgress(
        userServerId: _authService.currentUser!.serverId!,
        cardId: _currentCard.id,
        subjectId: _currentCard.subjectId,
        quality: 5,
        cardLevel: _currentCard.level,
      );
    } else {
      _sessionWrong++;
      _soundService.playWrong();
      await _progressService.recordProgress(
        userServerId: _authService.currentUser!.serverId!,
        cardId: _currentCard.id,
        subjectId: _currentCard.subjectId,
        quality: 0,
        cardLevel: _currentCard.level,
      );
      final card = _sessionQueue.removeAt(0);
      _sessionQueue.add(card);
    }

    if (_isAutoPlay) _scheduleAutoNext();
  }

  void _scheduleAutoNext() {
    if (!_isAutoPlay || _isAutoPlayWaiting) return;
    setState(() => _isAutoPlayWaiting = true);
    final delay =
        _isCorrect ? const Duration(seconds: 1) : const Duration(seconds: 2);
    Future.delayed(delay, () {
      if (mounted && _isAutoPlay && _isAnswered) _nextCard();
    });
  }

  void _nextCard() {
    setState(() => _isAutoPlayWaiting = false);
    player.stop();
    if (_isCorrect) {
      _sessionQueue.removeAt(0);
      _completedInSession++;
    }

    if (_sessionQueue.isNotEmpty) {
      setState(() => _currentCard = _sessionQueue.first);
      _setupMCQ();
    } else {
      _progressService.awardSubjectCompletionBonus(_totalInSession);
      _soundService.playCompleted();
      _showSessionSummary();
    }
  }

  void _showSessionSummary() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(context.t('session_complete')),
            content: Text('Correct: $_sessionCorrect, Wrong: $_sessionWrong'),
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
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;

              final mediaContent = Expanded(
                flex: 3,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12 : 32),
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
                        ],
                      ),
                    ),
                  ),
                ),
              );

              final sidebarContent = Container(
                padding: EdgeInsets.all(isMobile ? 20 : 32),
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LinearProgressIndicator(
                      value: progressValue,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(4),
                      color: headerColor,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentCard.getPrompt(lang).isNotEmpty
                          ? _currentCard.getPrompt(lang)
                          : context.t('select_an_answer'),
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 28,
                        fontWeight: FontWeight.bold,
                        color: headerColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (isMobile)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isAnswered
                                ? (_isCorrect ? Colors.green : Colors.red)
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                          color: _isAnswered
                              ? (_isCorrect
                                      ? Colors.green
                                      : Colors.red)
                                  .withValues(alpha: 0.1)
                              : null,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedIndex == -1 ? null : _selectedIndex,
                            hint: Text(context.t('select_an_answer')),
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down),
                            items: _options.asMap().entries.map((entry) {
                              return DropdownMenuItem<int>(
                                value: entry.key,
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(fontSize: 16),
                                ),
                              );
                            }).toList(),
                            onChanged: _isAnswered
                                ? null
                                : (val) {
                                    if (val != null) _selectOption(val);
                                  },
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: _options.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final opt = _options[index];
                            final isSelected = _selectedIndex == index;
                            final isCorrect = opt == _correctAnswerText;
                            Color? color;
                            if (_isAnswered) {
                              color =
                                  isCorrect
                                      ? Colors.green
                                      : (isSelected ? Colors.red : null);
                            } else if (isSelected)
                              color = headerColor;

                            return InkWell(
                              onTap: () => _selectOption(index),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: color ?? Colors.grey[300]!,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  color: color?.withValues(alpha: 0.1),
                                ),
                                child: Text(
                                  opt,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isAnswered ? _nextCard : null,
                            icon: const Icon(Icons.arrow_forward),
                            label: Text(context.t('next')),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size.fromHeight(isMobile ? 55 : 70),
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
                              if (_isAutoPlay && _isAnswered && !_isAutoPlayWaiting) {
                                _scheduleAutoNext();
                              }
                            });
                          },
                          icon: Icon(
                            _isAutoPlay ? Icons.pause_circle : Icons.play_circle,
                            size: 32,
                          ),
                          style: IconButton.styleFrom(
                            minimumSize: Size(isMobile ? 55 : 70, isMobile ? 55 : 70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );

              if (isMobile) {
                return Column(
                  children: [mediaContent, sidebarContent],
                );
              }

              bool isLeft = _authService.currentUser?.sidebarLeft ?? false;
              return Row(
                children:
                    isLeft
                        ? [
                          SizedBox(width: 450, child: sidebarContent),
                          Expanded(child: mediaContent),
                        ]
                        : [
                          Expanded(child: mediaContent),
                          SizedBox(width: 450, child: sidebarContent),
                        ],
              );
            },
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
