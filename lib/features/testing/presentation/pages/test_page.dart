import 'package:flutter/material.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/core/widgets/card_renderer.dart';
import 'package:aliolo/core/widgets/aliolo_image.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:aliolo/core/widgets/counting_grid.dart';
import 'package:aliolo/data/services/math_service.dart';
import 'package:aliolo/features/settings/presentation/pages/premium_upgrade_page.dart';

class TestOption {
  final String text;
  final String? imageUrl;
  final String id;

  TestOption({required this.text, this.imageUrl, required this.id});
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
  int _selectedIndex = -1;
  bool _isAnswered = false;
  bool _isCorrect = false;

  int _completedInSession = 0;
  int _totalInSession = 0;
  int _sessionCorrect = 0;
  bool _isSessionFinished = false;

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

  late String _languageCode;

  @override
  void initState() {
    super.initState();
    _languageCode = getIt<TestingLanguageService>().currentLanguageCode.value;
    final isPremium = getIt<SubscriptionService>().isPremium;
    _isAutoPlay =
        isPremium && (_authService.currentUser?.autoPlayEnabled ?? false);

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
    _completedInSession++;

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

    final allInSubject = await CardService().getCardsBySubject(
      _currentCard.subjectId,
    );

    if (_currentCard.mathOptions != null) {
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
          _currentImageIndex = 0;
          final video = _currentCard.getVideoUrl(lang);
          _showingVideo = video?.isNotEmpty ?? false;
        });
      }

    final lang = _languageCode.toLowerCase();
    final audio = _currentCard.getAudioUrl(lang);
    if (audio != null &&
        !_currentCard.isSpecialRenderer &&
        !_currentCard.isCountingRenderer) {
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
    final lang = _languageCode.toLowerCase();
    final list = card.getAnswerList(lang);
    if (list.isNotEmpty) return CardModel.capitalizeFirst(list.first);

    final enList = card.getAnswerList('en');
    if (enList.isNotEmpty) return CardModel.capitalizeFirst(enList.first);

    return '';
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
                if (!_currentCard.isSpecialRenderer &&
                    _currentCard.getAudioUrl(lang) != null)
                  IconButton(
                    icon: Icon(
                      Icons.volume_up,
                      color:
                          _currentCard.getAudioUrl(lang) != null
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                    ),
                    onPressed:
                        _currentCard.getAudioUrl(lang) != null
                            ? () async {
                              final url = _currentCard.getAudioUrl(lang);
                              if (url != null) {
                                await player.open(Media(url));
                                player.play();
                              }
                            }
                            : null,
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
                if (!kIsWeb) const WindowControls(color: Colors.white),
              ],
            ),
            floatingActionButton:
                _isAnswered
                    ? FloatingActionButton.extended(
                      onPressed: _nextCard,
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
                    )
                    : null,
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
                      Text(
                        _currentCard.getPrompt(lang),
                        style: TextStyle(
                          fontSize: 20,
                          color: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (_isAnswered)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children:
                              _currentCard
                                  .getAnswerList(lang)
                                  .map(
                                    (ans) => Text(
                                      CardModel.capitalizeFirst(ans),
                                      style: TextStyle(
                                        fontSize:
                                            _currentCard
                                                        .getAnswerList(lang)
                                                        .length >
                                                    1
                                                ? 24
                                                : 32,
                                        color:
                                            _isCorrect
                                                ? Colors.green
                                                : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                  .toList(),
                        )
                      else
                        Text(
                          '???',
                          style: TextStyle(
                            fontSize: 32,
                            color: headerColor.withValues(alpha: 0.3),
                            fontWeight: FontWeight.bold,
                          ),
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
                      final displayText = _currentCard.getDisplayText(lang).trim();
                      final hasAudio = _currentCard.getAudioUrl(lang) != null;
                      final hasVisual =
                          _currentCard.primaryImageUrl(lang) != null ||
                          _currentImages.isNotEmpty ||
                          _showingVideo ||
                          displayText.isNotEmpty ||
                          _currentCard.isSpecialRenderer;
                      final showAudioPrompt =
                          !_currentCard.isSpecialRenderer &&
                          hasAudio &&
                          !hasVisual;
                      final isAudioToImage =
                          !_currentCard.isSpecialRenderer &&
                          hasAudio &&
                          _currentImages.isNotEmpty &&
                          !showAudioPrompt;

                      Widget mediaContent = Center(
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 16 : 32),
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
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: isMobile ? 300 : 0,
                                  maxHeight:
                                      isMobile && !hasVisual
                                          ? 450
                                          : double.infinity,
                                ),
                                child: Stack(
                                  fit:
                                      isMobile
                                          ? StackFit.loose
                                          : StackFit.expand,
                                  alignment: Alignment.center,
                                  children: [
                                    if (_showingVideo)
                                      Video(controller: controller)
                                    else if (_currentCard.isCountingRenderer)
                                      CountingGrid(
                                        count: _currentCard.numericalAnswer,
                                        iconSize: isMobile ? 40 : 60,
                                      )
                                    else if (showAudioPrompt)
                                      Container(
                                        color: headerColor.withValues(
                                          alpha: 0.05,
                                        ),
                                        child: Center(
                                          child: Icon(
                                            Icons.hearing,
                                            size: 120,
                                            color: headerColor.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                        ),
                                      )
                                    else if (_currentImages.isNotEmpty)
                                      Container(
                                        color: Theme.of(context).cardColor,
                                        child: AlioloImage(
                                          imageUrl:
                                              _currentImages[_currentImageIndex],
                                          fit: BoxFit.contain,
                                          backgroundColor:
                                              headerColor.withValues(
                                                alpha: 0.05,
                                              ),
                                        ),
                                      )
                                    else if (_currentCard.isSpecialRenderer)
                                      CardRenderer(
                                        card: _currentCard,
                                        subject: _subject,
                                        languageCode: lang,
                                        fallbackColor: headerColor,
                                        fit: BoxFit.contain,
                                        textFontSize: isMobile ? 80 : 120,
                                      )
                                    else if (displayText.isNotEmpty)
                                      Center(
                                        child: Text(
                                          displayText,
                                          style: TextStyle(
                                            fontSize: isMobile ? 80 : 120,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    else if (_subject.isAlphabet)
                                      Center(
                                        child: Text(
                                          _currentCard
                                                  .getAnswer(lang)
                                                  .isNotEmpty
                                              ? _currentCard.getAnswer(lang)
                                              : _currentCard.getAnswer(
                                                'global',
                                              ),
                                          style: TextStyle(
                                            fontSize: isMobile ? 120 : 180,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black87,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      )
                                    else if (isAudioToImage)
                                      _buildAudioToImageGrid(
                                        headerColor,
                                        isMobile,
                                      )
                                    else if (_subject.isColors &&
                                        _currentCard.hexColor != null)
                                      Container(
                                        color: Color(
                                          int.parse(
                                            _currentCard.hexColor!.replaceFirst(
                                              '#',
                                              '0xFF',
                                            ),
                                          ),
                                        ),
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
                        ),
                      );

                      final optionsContent =
                          (!isAudioToImage || _currentCard.mathOptions != null)
                              ? Container(
                                width: isMobile ? double.infinity : 350,
                                padding: EdgeInsets.all(isMobile ? 24 : 32),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  boxShadow:
                                      isMobile
                                          ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.05,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, -5),
                                            ),
                                          ]
                                          : null,
                                ),
                                child: Column(
                                  mainAxisSize:
                                      isMobile
                                          ? MainAxisSize.min
                                          : MainAxisSize.max,
                                  children: [
                                    Text(
                                      context.t('select_an_answer'),
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[600],
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    if (isMobile)
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              crossAxisSpacing: 12,
                                              mainAxisSpacing: 12,
                                              childAspectRatio: 2.5,
                                            ),
                                        itemCount: _options.length,
                                        itemBuilder:
                                            (context, index) =>
                                                _buildOptionButton(
                                                  index,
                                                  headerColor,
                                                  isMobile,
                                                ),
                                      )
                                    else
                                      Expanded(
                                        child: Center(
                                          child: ListView.separated(
                                            shrinkWrap: true,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            itemCount: _options.length,
                                            separatorBuilder:
                                                (_, __) =>
                                                    const SizedBox(height: 12),
                                            itemBuilder:
                                                (context, index) =>
                                                    _buildOptionButton(
                                                      index,
                                                      headerColor,
                                                      isMobile,
                                                    ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              )
                              : const SizedBox.shrink();

                      if (isMobile) {
                        // For Audio to Image on mobile, fill screen and let grid handle its own scroll
                        if (isAudioToImage && _currentCard.mathOptions == null) {
                          return mediaContent;
                        }

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

                      bool isLeft =
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
        int cols = (availWidth / (targetSize + 16)).floor().clamp(
          1,
          isMobile ? 3 : 6,
        );

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
              width:
                  !needsScroll
                      ? (cols * actualSize) + ((cols - 1) * 16)
                      : double.infinity,
              child: GridView.builder(
                controller: _gridScrollController,
                shrinkWrap: !needsScroll,
                physics:
                    needsScroll
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
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
                    borderColor =
                        isCorrect
                            ? getIt<ThemeService>().success
                            : (isSelected
                                ? getIt<ThemeService>().error
                                : Colors.grey[300]);
                  } else if (isSelected)
                    borderColor = headerColor;
                  return InkWell(
                    onTap: () => _selectOption(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: borderColor ?? Theme.of(context).dividerColor,
                          width: isSelected || _isAnswered ? 4 : 2,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child:
                            opt.imageUrl != null
                                ? AlioloImage(
                                  imageUrl: opt.imageUrl!,
                                  fit: BoxFit.cover,
                                )
                                : Center(
                                  child: Text(
                                    opt.text,
                                    style: TextStyle(
                                      fontSize:
                                          _subject.isAlphabet
                                              ? (isMobile ? 80 : 120)
                                              : (isMobile ? 24 : 36),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
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
      color =
          isCorrect
              ? getIt<ThemeService>().success
              : (isSelected ? getIt<ThemeService>().error : null);
    } else if (isSelected)
      color = headerColor;

    // Dynamic font size based on text length
    double fontSize = isMobile ? 16 : 18;
    if (opt.text.length > 15)
      fontSize = isMobile ? 12 : 14;
    else if (opt.text.length > 10)
      fontSize = isMobile ? 14 : 16;

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
    _keyboardFocusNode.dispose();
    _scrollController.dispose();
    _gridScrollController.dispose();
    player.dispose();
    super.dispose();
  }
}
