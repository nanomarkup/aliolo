import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/data/services/sound_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/aliolo_image.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:aliolo/core/widgets/addition_grid.dart';
import 'package:aliolo/core/widgets/subtraction_grid.dart';
import 'package:aliolo/core/widgets/counting_grid.dart';
import 'package:aliolo/core/widgets/number_grid.dart';
import 'package:aliolo/core/widgets/multiplication_grid.dart';
import 'package:aliolo/core/widgets/division_grid.dart';
import 'package:aliolo/data/services/math_service.dart';

class TestOption {
  final String text;
  final String? imageUrl;
  final String id;

  TestOption({required this.text, this.imageUrl, required this.id});
}

class TestPage extends StatefulWidget {
  final List<SubjectCard> sessionCards;
  final String languageCode;

  const TestPage({super.key, required this.sessionCards, required this.languageCode});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final _authService = getIt<AuthService>();
  final _progressService = getIt<ProgressService>();
  final _soundService = getIt<SoundService>();

  late List<SubjectCard> _sessionQueue;
  late SubjectCard _currentSubjectCard;
  late CardModel _currentCard;
  late SubjectModel _subject;

  List<TestOption> _options = [];
  String _correctAnswerId = '';
  String _correctAnswerText = '';
  int _selectedIndex = -1;
  bool _isAnswered = false;
  bool _isCorrect = false;

  int _completedInSession = 0;
  int _totalInSession = 0;
  int _sessionCorrect = 0;

  late final Player player;
  late final VideoController controller;
  bool _showingVideo = false;
  List<String> _currentImages = [];
  int _currentImageIndex = 0;

  final _keyboardFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _gridScrollController = ScrollController();
  bool _isAutoPlay = false;
  bool _isAutoPlayWaiting = false;

  @override
  void initState() {
    super.initState();
    _isAutoPlay = _authService.currentUser?.autoPlayEnabled ?? false;
    player = Player();
    controller = VideoController(player);
    _sessionQueue = List.from(widget.sessionCards)..shuffle();
    _totalInSession = _sessionQueue.length;
    _setupNextCard();
  }

  void _setupNextCard() {
    if (_sessionQueue.isEmpty) {
      _finishSession();
      return;
    }

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

    _setupMCQ();
  }

  Future<void> _setupMCQ() async {
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
        final lang = widget.languageCode.toLowerCase();
        _currentImages = _currentCard.getImageUrls(lang);
        _currentImageIndex = 0;
        final video = _currentCard.getVideoUrl(lang);
        _showingVideo = _currentImages.isEmpty && (video?.isNotEmpty ?? false);
      });
    }

    final lang = widget.languageCode.toLowerCase();
    final audio = _currentCard.getAudioUrl(lang);
    if (audio != null &&
        !_subject.isAddition && !_subject.isSubtraction && !_subject.isCounting) {
      player.open(Media(audio));
      player.play();
    }
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (event.logicalKey == LogicalKeyboardKey.space ||
        event.logicalKey == LogicalKeyboardKey.enter) {
      if (_isAnswered) {
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
    final lang = widget.languageCode.toLowerCase();
    String ans = card.getAnswer(lang);
    if (ans.isEmpty && lang != 'en') ans = card.getAnswer('en');
    return ans;
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
      _soundService.playWrong();
      await _progressService.recordProgress(
        userServerId: _authService.currentUser!.serverId!,
        cardId: _currentCard.id,
        subjectId: _currentCard.subjectId,
        quality: 0,
        cardLevel: _currentCard.level,
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
    _completedInSession++;
    _setupNextCard();
  }

  void _finishSession() {
    Navigator.pop(context, true);
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
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
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

                    Widget mediaContent = Center(
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 16 : 32),
                        child: Card(
                          elevation: 4,
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                            side: BorderSide(color: headerColor.withValues(alpha: 0.1), width: 1),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: isMobile ? 250 : 0,
                              maxHeight: (isMobile && !isAudioToImage) ? 400 : double.infinity,
                            ),
                            child: Stack(
                              fit: isAudioToImage ? StackFit.loose : StackFit.expand,
                              children: [
                                if (_showingVideo)
                                  Video(controller: controller)
                                else if (isAudioToText)
                                  Container(
                                    color: headerColor.withValues(alpha: 0.05),
                                    child: Center(
                                      child: Icon(Icons.hearing, size: 120, color: headerColor.withValues(alpha: 0.5)),
                                    ),
                                  )
                                else if (_subject.isDivision)
                                  DivisionGrid(
                                    a: _currentCard.divisionParts?[0] ?? 0,
                                    b: _currentCard.divisionParts?[1] ?? 1,
                                    languageCode: lang,
                                    fontSize: isMobile ? 80 : 120,
                                    color: headerColor,
                                  )
                                else if (_subject.isMultiplication)
                                  MultiplicationGrid(
                                    a: _currentCard.multiplicationParts?[0] ?? 1,
                                    b: _currentCard.multiplicationParts?[1] ?? 0,
                                    languageCode: lang,
                                    fontSize: isMobile ? 80 : 120,
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
                                else if (isAudioToImage)
                                  _buildAudioToImageGrid(headerColor, isMobile)
                                else if (_subject.isNumbers)
                                  NumberGrid(
                                    displayChar: _currentCard.getNumericalChar(lang),
                                    fontSize: isMobile ? 80 : 120,
                                    color: headerColor,
                                  )
                                else if (_currentImages.isNotEmpty)
                                  AlioloImage(imageUrl: _currentImages[_currentImageIndex], fit: BoxFit.contain)
                                else
                                  const Icon(Icons.image_not_supported, size: 100, color: Colors.grey),                              ],
                            ),
                          ),
                        ),
                      ),
                    );

                    final optionsContent = (!isAudioToImage || (_subject.isMath && !_subject.isNumbers))
                        ? Container(
                            width: isMobile ? double.infinity : 350,
                            padding: EdgeInsets.all(isMobile ? 24 : 32),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              boxShadow: isMobile ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))] : null,
                            ),
                            child: Column(
                              mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
                              children: [
                                Text(
                                  context.t('select_an_answer'),
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600], letterSpacing: 1.1),
                                ),
                                const SizedBox(height: 20),
                                if (isMobile)
                                  GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 2.5,
                                    ),
                                    itemCount: _options.length,
                                    itemBuilder: (context, index) => _buildOptionButton(index, headerColor, isMobile),
                                  )
                                else
                                  Expanded(
                                    child: Center(
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        physics: const BouncingScrollPhysics(),
                                        itemCount: _options.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                                        itemBuilder: (context, index) => _buildOptionButton(index, headerColor, isMobile),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink();

                    if (isMobile) {
                      return SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          children: [
                            mediaContent,
                            if (optionsContent is! SizedBox) optionsContent,
                          ],
                        ),
                      );
                    }

                    bool isLeft = _authService.currentUser?.sidebarLeft ?? false;
                    return Row(
                      children: isLeft
                          ? [optionsContent, Expanded(flex: 3, child: mediaContent)]
                          : [Expanded(flex: 3, child: mediaContent), optionsContent],
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

Widget _buildAudioToImageGrid(Color headerColor, bool isMobile) {
  return LayoutBuilder(
    builder: (context, gridConstraints) {
      final n = _options.length;
      if (n == 0) return const SizedBox.shrink();

      final availWidth = gridConstraints.maxWidth - 32;
      final availHeight = gridConstraints.maxHeight - 32;

      // Target a comfortable square size
      final double targetSize = isMobile ? 140 : 180;
      
      // Calculate how many columns we can fit at target size
      int cols = (availWidth / (targetSize + 16)).floor().clamp(1, isMobile ? 3 : 6);
      
      // If we have few options, don't use more columns than options
      if (n < cols) cols = n;

      // Balancing logic: if n is not divisible by cols, try to find a better divisor nearby
      // This prevents cases like 4+2 for 6 options, turning it into 3+3.
      if (cols > 1 && n % cols != 0) {
        for (int c = cols - 1; c >= 2; c--) {
          if (n % c == 0) {
            cols = c;
            break;
          }
        }
      }

      // Calculate how many rows this creates
      final rows = (n / cols).ceil();
      
      // Calculate actual size to fit perfectly in width
      final double actualSize = (availWidth - (cols - 1) * 16) / cols;
      
      // If total height with actualSize exceeds availHeight, we MUST scroll or shrink.
      // But user wants "Adjustable", so we center it.
      final totalGridHeight = (rows * actualSize) + ((rows - 1) * 16);
      final bool needsScroll = totalGridHeight > availHeight;

      return Container(
        alignment: Alignment.center,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            // If it doesn't need scroll, constrain width so it doesn't stretch too much
            width: !needsScroll ? (cols * actualSize) + ((cols - 1) * 16) : double.infinity,
            child: GridView.builder(
              controller: _gridScrollController,
              shrinkWrap: !needsScroll,
              physics: needsScroll ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              itemCount: n,
              itemBuilder: (context, index) {
                final opt = _options[index];
                final isSelected = _selectedIndex == index;
                final isCorrect = opt.id == _correctAnswerId;
                Color? borderColor;
                if (_isAnswered) {
                  borderColor = isCorrect ? getIt<ThemeService>().success : (isSelected ? getIt<ThemeService>().error : Colors.grey[300]);
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
                        : Center(child: Text(opt.text, style: TextStyle(fontSize: isMobile ? 24 : 36, fontWeight: FontWeight.bold))),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildOptionButton(int index, Color headerColor, bool isMobile) {
  final opt = _options[index];
  final isSelected = _selectedIndex == index;
  final isCorrect = opt.id == _correctAnswerId;
  Color? color;
  if (_isAnswered) {
    color = isCorrect ? getIt<ThemeService>().success : (isSelected ? getIt<ThemeService>().error : null);
  } else if (isSelected) color = headerColor;

  // Dynamic font size based on text length
  double fontSize = isMobile ? 16 : 18;
  if (opt.text.length > 15) fontSize = isMobile ? 12 : 14;
  else if (opt.text.length > 10) fontSize = isMobile ? 14 : 16;

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
          Text('${index + 1}.', style: TextStyle(fontSize: fontSize * 0.8, color: Colors.grey[500], fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              opt.text, 
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600), 
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          ),
        ],
      ),
    ),
  );
}

  @override
  void dispose() {
    _keyboardFocusNode.dispose();
    _scrollController.dispose();
    _gridScrollController.dispose();
    player.dispose();
    super.dispose();
  }
}
