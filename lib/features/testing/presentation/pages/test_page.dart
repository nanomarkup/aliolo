import 'dart:math';
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
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/math_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/aliolo_image.dart';
import 'package:aliolo/core/widgets/counting_grid.dart';
import 'package:aliolo/core/widgets/addition_grid.dart';
import 'package:aliolo/core/widgets/subtraction_grid.dart';
import 'package:aliolo/core/widgets/number_grid.dart';
import 'package:aliolo/core/widgets/multiplication_grid.dart';
import 'package:aliolo/core/widgets/division_grid.dart';

class TestPage extends StatefulWidget {
  final List<SubjectCard> sessionCards;
  final String languageCode;

  const TestPage({super.key, required this.sessionCards, required this.languageCode});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late SubjectCard _currentSubjectCard;
  CardModel get _currentCard => _currentSubjectCard.card;
  SubjectModel get _subject => _currentSubjectCard.subject;

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
  List<SubjectCard> _sessionQueue = [];
  int _completedInSession = 0;
  int _totalInSession = 0;
  int _sessionCorrect = 0;
  int _sessionWrong = 0;

  bool _isAutoPlay = false;
  bool _isAutoPlayWaiting = false;

  final _authService = AuthService();
  final _soundService = SoundService();
  final _progressService = ProgressService();
  final _keyboardFocusNode = FocusNode();

  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) windowManager.setResizable(true);
    _isAutoPlay = _authService.currentUser?.autoPlayEnabled ?? false;
    
    _sessionQueue = List.from(widget.sessionCards);
    _totalInSession = _sessionQueue.length;

    if (_sessionQueue.isNotEmpty) {
      _currentSubjectCard = _sessionQueue.first;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupMCQ();
      });
    }
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (_isAnswered) {
        _nextCard();
      }
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
      options = _currentCard.mathOptions ?? [];
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

    if (mounted) {
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
    }

    final audio = _currentCard.getAudioUrl(lang);
    if (audio != null &&
        !_subject.isNumbers && !_subject.isAddition && !_subject.isSubtraction) {
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
      // Re-add card to end of queue if wrong
      final item = _sessionQueue.removeAt(0);
      _sessionQueue.add(item);
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
      setState(() => _currentSubjectCard = _sessionQueue.first);
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

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageCode.toLowerCase();
    final pillar = pillars.firstWhere(
      (p) => p.id == _subject.pillarId,
      orElse: () => pillars.first,
    );
    final headerColor = pillar.getColor();

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
            appBar: AppBar(
              automaticallyImplyLeading: false,
              title: Text(_subject.getName(widget.languageCode)),
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
                          else if (_subject.isDivision)
                            DivisionGrid(
                              a: _currentCard.divisionParts?[0] ?? 0,
                              b: _currentCard.divisionParts?[1] ?? 1,
                              languageCode: lang,
                              fontSize: isMobile ? 120 : 200,
                              color: headerColor,
                            )
                          else if (_subject.isMultiplication)
                            MultiplicationGrid(
                              a: _currentCard.multiplicationParts?[0] ?? 1,
                              b: _currentCard.multiplicationParts?[1] ?? 0,
                              languageCode: lang,
                              fontSize: isMobile ? 120 : 200,
                              color: headerColor,
                            )
                          else if (_subject.isNumbers)
                            NumberGrid(
                              displayChar: _currentCard.getNumericalChar(lang),
                              fontSize: isMobile ? 120 : 200,
                              color: headerColor,
                            )
                          else if (_subject.isSubtraction)
                            SubtractionGrid(
                              totalSum: _currentCard.numericalAnswer,
                              maxOperand: _subject.maxOperand,
                              iconSize: isMobile ? 40 : 60,
                            )
                          else if (_subject.isAddition)
                            AdditionGrid(
                              totalSum: _currentCard.numericalAnswer,
                              maxOperand: _subject.maxOperand,
                              iconSize: isMobile ? 40 : 60,
                            )
                          else if (_currentCard.subjectId == '68232807-b9cd-4cff-872c-c398444f85e2' ||
                              _currentCard.subjectId == 'c3548727-65f4-4e0c-939c-56135b4eb543')
                            CountingGrid(
                              count: _currentCard.numericalAnswer,
                              iconSize: isMobile ? 40 : 60,
                            )
                          else if (_currentImages.isNotEmpty)
                            AlioloImage(
                              imageUrl: _currentImages[_currentImageIndex],
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
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
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
                          const SizedBox(height: 24),
                          if (isMobile)
                            Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
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
                                  value:
                                      _selectedIndex == -1
                                          ? null
                                          : _selectedIndex,
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
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 500),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: _options.length,
                                separatorBuilder:
                                    (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final opt = _options[index];
                                  final isSelected = _selectedIndex == index;
                                  final isCorrect = opt == _correctAnswerText;
                                  Color? color;
                                  if (_isAnswered) {
                                    color =
                                        isCorrect
                                            ? Colors.green
                                            : (isSelected
                                                ? Colors.red
                                                : null);
                                  } else if (isSelected) color = headerColor;

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
                                        borderRadius:
                                            BorderRadius.circular(16),
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
                        ],
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
                        if ((_currentCard.testMode == 'audio_to_text' ||
                                _currentCard.testMode == 'audio_to_image') &&
                            _currentCard.getAudioUrl(lang) != null &&
                            !_subject.isNumbers && !_subject.isAddition && !_subject.isSubtraction) ...[
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            onPressed: () async {
                              final url = _currentCard.getAudioUrl(lang);
                              if (url != null) {
                                await player.open(Media(url));
                                player.play();
                              }
                            },
                            icon: const Icon(Icons.volume_up, size: 28),
                            style: IconButton.styleFrom(
                              minimumSize: Size(
                                isMobile ? 55 : 70,
                                isMobile ? 55 : 70,
                              ),
                            ),
                            tooltip: 'Replay Audio',
                          ),
                        ],
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          onPressed: () {
                            final newVal = !_isAutoPlay;
                            _authService.updateAutoPlayPreference(newVal);
                            setState(() {
                              _isAutoPlay = newVal;
                              if (_isAutoPlay &&
                                  _isAnswered &&
                                  !_isAutoPlayWaiting) {
                                _scheduleAutoNext();
                              }
                            });
                          },
                          icon: Icon(
                            _isAutoPlay ? Icons.pause_circle : Icons.play_circle,
                            size: 32,
                          ),
                          style: IconButton.styleFrom(
                            minimumSize: Size(
                              isMobile ? 55 : 70,
                              isMobile ? 55 : 70,
                            ),
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
        ),
      );
    },
  );
}

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    player.dispose();
    super.dispose();
  }
}
