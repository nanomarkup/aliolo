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
  bool _isAutoPlayWaiting = false;
  final _random = Random();

  int _autoPlayingOptionIndex = -1;
  StreamSubscription? _playerSubscription;
  Timer? _optionAutoplayTimer;

  late String _languageCode;

  @override
  void initState() {
    super.initState();
    _languageCode = getIt<TestingLanguageService>().currentLanguageCode.value;
    final isPremium = getIt<SubscriptionService>().isPremium;
    _isAutoPlay =
        isPremium && (_authService.currentUser?.autoPlayEnabled ?? false);
    _selectedMode = parseTestModeChoice(_authService.currentUser?.testMode);

    _audioPlayer.onPlayerComplete.listen((_) {
      if (_autoPlayingOptionIndex != -1) {
        _onOptionAudioCompleted();
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
    setState(() => _autoPlayingOptionIndex = -1);
  }

  void _startOptionsAutoplay() {
    if (!_isReverseMode) return;

    final lang = _languageCode.toLowerCase();
    final correctImageUrl = _currentCard.primaryImageUrl(lang) ??
        _currentCard.primaryImageUrl('global') ??
        _currentCard.primaryImageUrl('en');
    final correctVideoUrl = _currentCard.getVideoUrl(lang);
    final hasMeaningfulDisplayText = _currentCard.hasMeaningfulDisplayText(lang);
    final displayText =
        hasMeaningfulDisplayText ? _currentCard.getDisplayText(lang).trim() : '';
    final deduplicatedText =
        (_correctAnswerText.isNotEmpty &&
                displayText.toLowerCase() == _correctAnswerText.toLowerCase())
            ? ''
            : displayText;
    final hasCorrectVisual =
        _currentCard.isSpecialRenderer ||
        _currentCard.isCountingRenderer ||
        _currentCard.isColors ||
        (correctVideoUrl != null && correctVideoUrl.isNotEmpty) ||
        (correctImageUrl != null && correctImageUrl.isNotEmpty) ||
        deduplicatedText.isNotEmpty;
    final isAudioTest =
        !hasCorrectVisual && (_currentCard.getAudioUrl(lang)?.isNotEmpty ?? false);

    if (!isAudioTest) return;

    if (_options.isNotEmpty) {
      _playOptionSequentially(0);
    }
  }

  void _playOptionSequentially(int index) {
    if (_isAnswered || !mounted) return;
    if (index >= _options.length) {
      setState(() => _autoPlayingOptionIndex = -1);
      return;
    }

    setState(() => _autoPlayingOptionIndex = index);
    final opt = _options[index];
    final url = opt.card?.getAudioUrl(_languageCode.toLowerCase());
    if (url != null && url.isNotEmpty) {
      _audioPlayer.play(UrlSource(url));
    } else {
      // skip if no audio
      _onOptionAudioCompleted();
    }
  }

  void _onOptionAudioCompleted() {
    if (_autoPlayingOptionIndex == -1 || _isAnswered || !mounted) return;

    _optionAutoplayTimer?.cancel();
    _optionAutoplayTimer = Timer(const Duration(seconds: 1), () {
      _playOptionSequentially(_autoPlayingOptionIndex + 1);
    });
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
                (c) => TestOption(
                  text: _getDisplayAnswer(c),
                  card: c,
                  id: c.id,
                ),
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
            _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
            _videoController!.initialize().then((_) {
              if (mounted) {
                setState(() {
                  _hasVideo = true;
                });
                _videoController!.play();
              }
            });
          } else {
            _hasVideo = false;
          }
        });
      }

    final lang = _languageCode.toLowerCase();
    final audio = _currentCard.getAudioUrl(lang);
    if (audio != null &&
        !_isReverseMode &&
        !_currentCard.isSpecialRenderer &&
        !_currentCard.isCountingRenderer) {
      _audioPlayer.play(UrlSource(audio));
    }

    if (_isReverseMode) {
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
                  color:
                      selected ? headerColor : Colors.grey[700],
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(mode.label)),
                if (selected)
                  Icon(
                    Icons.check,
                    size: 18,
                    color: headerColor,
                  ),
              ],
            ),
          );
        }).toList();
      },
    );
  }

  Widget _buildForwardMediaContent({
    required BuildContext context,
    required bool isMobile,
    required Color headerColor,
    required String lang,
  }) {
    final audioUrl = _currentCard.getAudioUrl(lang);
    final hasAudio = audioUrl != null && audioUrl.isNotEmpty;
    
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
      onPlayAudio: hasAudio ? () async {
        if (audioUrl.isNotEmpty) {
          await _audioPlayer.play(UrlSource(audioUrl));
        }
      } : null,
      hasAudio: hasAudio,
      headerText: _isReverseMode ? _correctAnswerText : _currentCard.getPrompt(lang).trim(),
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
        _isReverseMode && _isAnswered
            ? FontWeight.bold
            : FontWeight.w500;

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
                                color:
                                    _isCorrect ? Colors.green : Colors.red,
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
            floatingActionButton:
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 120),
                  opacity: (_isAnswered && !_isAdvancing) ? 1.0 : 0.45,
                  child: FloatingActionButton.extended(
                    onPressed:
                        (_isAnswered && !_isAdvancing) ? _nextCard : null,
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
                      final correctImageUrl = _currentCard.primaryImageUrl(lang) ??
                                              _currentCard.primaryImageUrl('global') ??
                                              _currentCard.primaryImageUrl('en');
                      final correctVideoUrl = _currentCard.getVideoUrl(lang);
                      final hasMeaningfulDisplayText = _currentCard.hasMeaningfulDisplayText(lang);
                      final displayText = hasMeaningfulDisplayText ? _currentCard.getDisplayText(lang).trim() : '';
                      final deduplicatedText = (_correctAnswerText.isNotEmpty && displayText.toLowerCase() == _correctAnswerText.toLowerCase()) ? '' : displayText;
                      final hasCorrectVisual = _currentCard.isSpecialRenderer ||
                                               _currentCard.isCountingRenderer ||
                                               _currentCard.isColors ||
                                               (correctVideoUrl != null && correctVideoUrl.isNotEmpty) ||
                                               (correctImageUrl != null && correctImageUrl.isNotEmpty) ||
                                               deduplicatedText.isNotEmpty;
                      final isAudioTest = !hasCorrectVisual && (_currentCard.getAudioUrl(lang)?.isNotEmpty ?? false);
                      
                      // Calculate the absolute maximum columns based on width
                      final maxPossibleColumns = isAudioTest 
                          ? (constraints.maxWidth / 300).floor().clamp(2, 4)
                          : (constraints.maxWidth / 400).floor().clamp(2, 3);
                      
                      // Balanced crossAxisCount logic:
                      // Distribute items as evenly as possible across rows.
                      final int numOptions = _options.length;
                      int crossAxisCount;
                      if (numOptions == 0) {
                        crossAxisCount = maxPossibleColumns;
                      } else if (numOptions <= maxPossibleColumns) {
                        crossAxisCount = numOptions;
                      } else {
                        final int rows = (numOptions / maxPossibleColumns).ceil();
                        crossAxisCount = (numOptions / rows).ceil();
                      }
                      // Safety clamp
                      crossAxisCount = crossAxisCount.clamp(2, maxPossibleColumns);

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
                            _isReverseMode || isMobile
                                ? double.infinity
                                : 350,
                        padding: EdgeInsets.all(isMobile ? 24 : 32),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          boxShadow:
                              isMobile
                                  ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
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
                                        childAspectRatio: isAudioTest ? (isMobile ? 2.5 : 3.0) : 1.0,
                                      ),
                                  itemCount: _options.length,
                                  itemBuilder:
                                      (context, index) =>
                                          _buildOptionButton(
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
                                        (_, __) => const SizedBox(
                                          height: 12,
                                        ),
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

                      if (_isReverseMode) {
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
                              mediaContent,
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
                                  Expanded(flex: 3, child: mediaContent),
                                ]
                                : [
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

  Widget _buildOptionButton(int index, Color headerColor, bool isMobile, bool isAudioTest) {
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
          child: isAudioTest
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
                        color: hasOptAudio
                            ? headerColor
                            : Colors.grey.withValues(alpha: 0.3),
                      ),
                      onPressed:
                          hasOptAudio
                              ? () async {
                                if (optAudioUrl.isNotEmpty) {
                                  await _audioPlayer.play(UrlSource(optAudioUrl));
                                }
                              }
                              : null,
                    ),
                  ],
                )
              : Stack(
                  children: [
                    Positioned.fill(
                      child: CardRenderer(
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
                                    await _audioPlayer.play(UrlSource(optAudioUrl));
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
    _keyboardFocusNode.dispose();
    _scrollController.dispose();
    _gridScrollController.dispose();
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
}