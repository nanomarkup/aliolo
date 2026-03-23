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

class TestOption {
  final String text;
  final String? imageUrl;
  final String id;

  TestOption({required this.text, this.imageUrl, required this.id});
}

class _TestPageState extends State<TestPage> {
  late SubjectCard _currentSubjectCard;
  CardModel get _currentCard => _currentSubjectCard.card;
  SubjectModel get _subject => _currentSubjectCard.subject;

  // MCQ State
  List<TestOption> _options = [];
  int _selectedIndex = -1;
  bool _isAnswered = false;
  bool _isCorrect = false;
  String _correctAnswerText = '';
  String _correctAnswerId = '';

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
    final lang = widget.languageCode.toLowerCase();
    _correctAnswerText = _getDisplayAnswer(_currentCard);
    _correctAnswerId = _currentCard.id;
    final user = _authService.currentUser;

    List<TestOption> options = [];

    if (_subject.isMath && !_subject.isNumbers) {
      _correctAnswerId = _currentCard.numericalAnswer.toString();
      List<String> mathOpts = _currentCard.mathOptions ?? [];
      if (mathOpts.isEmpty) {
        final optCount = user?.optionsCount ?? 6;
        mathOpts = MathService().generateDistractors(_currentCard.numericalAnswer, optCount);
      }
      options = mathOpts.map((o) => TestOption(text: o, id: o)).toList();
    } else {
      final allInSubject = await CardService().getCardsBySubject(
        _currentCard.subjectId,
      );
      
      final distractors = allInSubject
          .where((c) => c.id != _currentCard.id)
          .toList();
      distractors.shuffle();

      final optCount = user?.optionsCount ?? 6;
      final selectedDistractors = distractors.take(optCount - 1).toList();

      options = selectedDistractors.map((c) => TestOption(
        text: _getDisplayAnswer(c),
        imageUrl: c.primaryImageUrl,
        id: c.id,
      )).toList();

      options.add(TestOption(
        text: _correctAnswerText,
        imageUrl: _currentCard.primaryImageUrl,
        id: _currentCard.id,
      ));
      
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
        !_subject.isAddition && !_subject.isSubtraction && !_subject.isCounting) {
      player.open(Media(audio));
      player.play();
    }
  }

  Future<void> _selectOption(int index) async {
    if (_isAnswered) return;
    final correct = _options[index].id == _correctAnswerId;
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
              title: Text(_subject.getName(widget.languageCode), style: const TextStyle(fontSize: 18)),
              backgroundColor: headerColor,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                ),
                if ((_currentCard.testMode == 'audio_to_text' || _currentCard.testMode == 'audio_to_image') &&
                    _currentCard.getAudioUrl(lang) != null &&
                    !_subject.isNumbers && !_subject.isAddition && !_subject.isSubtraction && !_subject.isCounting)
                  IconButton(
                    icon: const Icon(Icons.volume_up),
                    onPressed: () async {
                      final url = _currentCard.getAudioUrl(lang);
                      if (url != null) {
                        await player.open(Media(url));
                        player.play();
                      }
                    },
                    tooltip: 'Replay Audio',
                  ),
                IconButton(
                  icon: Icon(_isAutoPlay ? Icons.pause_circle : Icons.play_circle),
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
                  tooltip: 'Auto-play',
                ),
                if (!kIsWeb) const WindowControls(color: Colors.white),
              ],
            ),
            floatingActionButton: _isAnswered 
              ? FloatingActionButton.extended(
                  onPressed: _nextCard,
                  backgroundColor: headerColor,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(context.t('next'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                )
              : null,
          body: Column(
            children: [
              // Integrated Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                color: headerColor.withValues(alpha: 0.05),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      _currentCard.getPrompt(lang),
                      style: TextStyle(fontSize: 20, color: Colors.grey[700], fontWeight: FontWeight.w500),
                    ),
                    if (_isAnswered)
                      Text(
                        _correctAnswerText,
                        style: TextStyle(fontSize: 32, color: _isCorrect ? Colors.green : Colors.red, fontWeight: FontWeight.bold),
                      )
                    else
                      Text(
                        '???',
                        style: TextStyle(fontSize: 32, color: headerColor.withValues(alpha: 0.3), fontWeight: FontWeight.bold),
                      ),
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 800;
                    final isAudioToText = _currentCard.testMode == 'audio_to_text';
                    final isAudioToImage = _currentCard.testMode == 'audio_to_image';

                    return Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Card(
                                elevation: 4,
                                clipBehavior: Clip.antiAlias,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(color: headerColor.withValues(alpha: 0.1), width: 1),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (_showingVideo)
                                      Video(controller: controller)
                                    else if (_currentImages.isNotEmpty)
                                      AlioloImage(imageUrl: _currentImages[_currentImageIndex], fit: BoxFit.contain)
                                    else if (isAudioToText)
                                      Container(
                                        color: headerColor.withValues(alpha: 0.05),
                                        child: Center(
                                          child: Icon(Icons.hearing, size: 120, color: headerColor.withValues(alpha: 0.5)),
                                        ),
                                      )
                                    else if (isAudioToImage)
                                      LayoutBuilder(
                                        builder: (context, gridConstraints) {
                                          final n = _options.length;
                                          if (n == 0) return const SizedBox.shrink();
                                          final availWidth = gridConstraints.maxWidth - 32;
                                          final availHeight = gridConstraints.maxHeight - 32;
                                          double bestCellSize = 0;
                                          int bestCols = 2;
                                          for (int cols = 1; cols <= 4; cols++) {
                                            final rows = (n / cols).ceil();
                                            final cellW = (availWidth - (cols - 1) * 16) / cols;
                                            final cellH = (availHeight - (rows - 1) * 16) / rows;
                                            if (cellW > 0 && cellH > 0) {
                                              final size = min(cellW, cellH);
                                              if (size > bestCellSize) {
                                                bestCellSize = size;
                                                bestCols = cols;
                                              }
                                            }
                                          }
                                          final rows = (n / bestCols).ceil();
                                          final aspectRatio = ((availWidth - (bestCols - 1) * 16) / bestCols) / ((availHeight - (rows - 1) * 16) / rows);
                                          return Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: GridView.builder(
                                              shrinkWrap: true,
                                              physics: const NeverScrollableScrollPhysics(),
                                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                                crossAxisCount: bestCols,
                                                crossAxisSpacing: 16,
                                                mainAxisSpacing: 16,
                                                childAspectRatio: aspectRatio,
                                              ),
                                              itemCount: n,
                                              itemBuilder: (context, index) {
                                                final opt = _options[index];
                                                final isSelected = _selectedIndex == index;
                                                final isCorrect = opt.id == _correctAnswerId;
                                                Color? borderColor;
                                                if (_isAnswered) {
                                                  borderColor = isCorrect ? Colors.green : (isSelected ? Colors.red : Colors.grey[300]);
                                                } else if (isSelected) borderColor = headerColor;
                                                return InkWell(
                                                  onTap: () => _selectOption(index),
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(color: borderColor ?? Colors.grey[300]!, width: isSelected || _isAnswered ? 4 : 2),
                                                    ),
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(12),
                                                      child: opt.imageUrl != null 
                                                        ? AlioloImage(imageUrl: opt.imageUrl!, fit: BoxFit.cover)
                                                        : Center(child: Text(opt.text, style: TextStyle(fontSize: isMobile ? 20 : 32, fontWeight: FontWeight.bold))),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          );
                                        },
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
                                        displayChar: _currentCard.getNumericalChar(lang),
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
                                    else if (_currentCard.subjectId == '68232807-b9cd-4cff-872c-c398444f85e2' ||
                                        _currentCard.subjectId == 'c3548727-65f4-4e0c-939c-56135b4eb543')
                                      CountingGrid(
                                        count: _currentCard.numericalAnswer,
                                        iconSize: 60,
                                      )
                                    else
                                      const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (!isAudioToImage || (_subject.isMath && !_subject.isNumbers))
                          SizedBox(
                            width: isMobile ? 120 : 300,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                              color: Theme.of(context).colorScheme.surface,
                              child: Column(
                                children: [
                                  Text(context.t('select_an_answer'), style: TextStyle(fontSize: isMobile ? 12 : 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: ListView.separated(
                                      itemCount: _options.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final opt = _options[index];
                                        final isSelected = _selectedIndex == index;
                                        final isCorrect = opt.id == _correctAnswerId;
                                        Color? color;
                                        if (_isAnswered) {
                                          color = isCorrect ? Colors.green : (isSelected ? Colors.red : null);
                                        } else if (isSelected) color = headerColor;
                                        return InkWell(
                                          onTap: () => _selectOption(index),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              border: Border.all(color: color ?? Colors.grey[300]!, width: 2),
                                              borderRadius: BorderRadius.circular(12),
                                              color: color?.withValues(alpha: 0.1),
                                            ),
                                            child: Text(opt.text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    player.dispose();
    super.dispose();
  }
}
