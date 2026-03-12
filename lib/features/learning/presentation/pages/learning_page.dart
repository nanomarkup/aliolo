import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/sound_service.dart';
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/math_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/management/presentation/pages/manage_cards_page.dart';
import 'package:aliolo/features/management/presentation/pages/user_management_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';

class LearningPage extends StatefulWidget {
  final CardModel card;
  final String languageCode;

  const LearningPage({super.key, required this.card, required this.languageCode});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  late CardModel _currentCard;
  
  // MCQ State
  List<String> _options = [];
  int _selectedIndex = -1;
  bool _isAnswered = false;
  bool _isCorrect = false;
  String _correctAnswerText = '';

  // Multi-image State
  List<String> _currentImages = [];
  int _currentImageIndex = 0;
  bool _showingVideo = false;

  // Session State
  List<CardModel> _sessionQueue = [];
  int _completedInSession = 0;
  int _totalInSession = 0;

  final FocusNode _keyboardFocus = FocusNode();
  final _authService = AuthService();
  final _soundService = SoundService();
  final _progressService = ProgressService();

  late final Player player = Player();
  late final VideoController controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    _currentCard = widget.card;
    _initSession();
  }

  Future<void> _initSession() async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (_currentCard.subjectId == 'Math') {
      final List<CardModel> sessionCards = [];
      final int mathLevel = widget.card.level;
      
      for (int i = 0; i < (user.sessionSize); i++) {
        final problem = MathService().generateProblem(mathLevel);
        final card = MathService().createVirtualCard(problem, mathLevel);
        sessionCards.add(card);
      }
      setState(() {
        _sessionQueue = sessionCards;
        _totalInSession = _sessionQueue.length;
        _currentCard = _sessionQueue.first;
        _setupMCQ();
        _loadVideo();
      });
      return;
    }

    final allCards = await CardService().getCardsBySubject(_currentCard.subjectId);
    if (allCards.isEmpty) return;

    final lang = widget.languageCode.toLowerCase();
    final langFiltered = allCards.where((c) => c.answers.containsKey(lang) || c.answers.containsKey('en')).toList();
    langFiltered.shuffle();

    final size = user.sessionSize;
    final List<CardModel> sessionCards = langFiltered.take(size).toList();
    
    if (sessionCards.isNotEmpty) {
      setState(() {
        _sessionQueue = sessionCards;
        _totalInSession = _sessionQueue.length;
        _currentCard = _sessionQueue.first;
        _setupMCQ();
        _loadVideo();
      });
    }
  }

  void _loadVideo() {
  }

  String _getDisplayPrompt(CardModel card) {
    final lang = widget.languageCode.toLowerCase();
    return card.prompts[lang] ?? card.prompts['en'] ?? card.prompts.values.firstOrNull ?? '';
  }

  String _getDisplayAnswer(CardModel card) {
    final lang = widget.languageCode.toLowerCase();
    final ans = card.answers[lang] ?? card.answers['en'] ?? card.answers.values.firstOrNull ?? '';

    if (ans.contains(';')) {
      final parts = ans.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      return parts.isNotEmpty ? parts[Random().nextInt(parts.length)] : ans;
    }
    return ans;
  }

  Future<void> _setupMCQ() async {
    _correctAnswerText = _getDisplayAnswer(_currentCard);
    final user = _authService.currentUser;

    List<String> options = [];

    if (_currentCard.subjectId == 'Math') {
      if (_currentCard.mathOptions != null) {
        options = List.from(_currentCard.mathOptions!);
      }
    } else {
      final allInSubject = await CardService().getCardsBySubject(_currentCard.subjectId);
      final lang = widget.languageCode.toLowerCase();
      final validOptions = allInSubject
          .where((c) => c.id != _currentCard.id)
          .where((c) => c.answers.containsKey(lang) || c.answers.containsKey('en'))
          .map((c) => _getDisplayAnswer(c))
          .toSet()
          .toList();
      validOptions.removeWhere((opt) => opt == _correctAnswerText);
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
      
      _currentImages = [
        if (_currentCard.imageUrl != null && _currentCard.imageUrl!.isNotEmpty) _currentCard.imageUrl!,
        ..._currentCard.imageUrls.where((u) => u != _currentCard.imageUrl),
      ];
      _currentImageIndex = 0;
      _showingVideo = _currentImages.isEmpty && (_currentCard.videoUrl?.isNotEmpty ?? false);
    });
    
    if (_showingVideo && _currentCard.videoUrl != null) {
      player.open(Media(_currentCard.videoUrl!));
      player.play();
    }
  }

  void _selectOption(int index) {
    if (_isAnswered) return;

    final selectedValue = _options[index];
    final correct = selectedValue == _correctAnswerText;

    setState(() {
      _selectedIndex = index;
      _isAnswered = true;
      _isCorrect = correct;
    });

    if (correct) {
      _soundService.playCorrect();
      _progressService.recordCorrectAnswer(
        _currentCard.id, 
        _currentCard.subjectId,
        quality: 5,
        cardLevel: _currentCard.level,
      );
    } else {
      _soundService.playWrong();
      _progressService.recordCorrectAnswer(
        _currentCard.id, 
        _currentCard.subjectId,
        quality: 0,
        cardLevel: _currentCard.level,
      );
      final card = _sessionQueue.removeAt(0);
      _sessionQueue.add(card);
    }
  }

  void _nextCard() {
    player.stop();
    if (_isCorrect) {
      _sessionQueue.removeAt(0);
      _completedInSession++;
    }

    if (_sessionQueue.isNotEmpty) {
      setState(() {
        _currentCard = _sessionQueue.first;
      });
      _setupMCQ();
      _loadVideo();
    } else {
      _progressService.awardSubjectCompletionBonus();
      _soundService.playCompleted();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(context.t('session_complete')),
          content: Text(context.t('finished_session', args: {'count': _totalInSession.toString()})),
          actions: [
            TextButton(
              focusNode: FocusNode(canRequestFocus: true)..requestFocus(),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              }, 
              child: Text(context.t('back_to_subjects'))
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isLeft = _authService.currentUser?.sidebarLeft ?? false;
    const appBarColor = Colors.white;
    const currentSessionColor = ThemeService.mainColor;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        Color masteryColor = Colors.grey[400]!;
        String masteryLabel = context.t('new');
        double progressValue = _totalInSession > 0 ? _completedInSession / _totalInSession : 0.0;

        Widget sidebar = Container(
          width: 450,
          padding: const EdgeInsets.all(32),
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            children: [
              // Progress bar at the top
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progressValue,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(currentSessionColor),
                ),
              ),
              
              // Centered prompt and answers
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _getDisplayPrompt(_currentCard).isNotEmpty ? _getDisplayPrompt(_currentCard) : context.t('select_an_answer'), 
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: currentSessionColor),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(_options.length, (index) {
                          final option = _options[index];
                          final isSelected = _selectedIndex == index;
                          final correctValue = _correctAnswerText;
                          
                          Color? tileColor;
                          if (_isAnswered) {
                            if (option == correctValue) tileColor = Colors.green.withValues(alpha: 0.2);
                            else if (isSelected && !_isCorrect) tileColor = Colors.red.withValues(alpha: 0.2);
                          } else if (isSelected) {
                            tileColor = currentSessionColor.withValues(alpha: 0.1);
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              onTap: () => _selectOption(index),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: _isAnswered && option == correctValue ? Colors.green : (isSelected ? currentSessionColor : Colors.grey[300]!),
                                    width: 2.5,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  color: tileColor,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36, height: 36,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? currentSessionColor : Colors.grey[200]),
                                      child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black))),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(child: Text(option, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500))),
                                    if (_isAnswered && option == correctValue) const Icon(Icons.check_circle, color: Colors.green, size: 28),
                                    if (_isAnswered && isSelected && !_isCorrect) const Icon(Icons.cancel, color: Colors.red, size: 28),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Next button at the bottom
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton.icon(
                  onPressed: _isAnswered ? _nextCard : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(context.t('next'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAnswered ? (_isCorrect ? Colors.green : Colors.blueGrey) : currentSessionColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    disabledBackgroundColor: Colors.grey[300],
                    disabledForegroundColor: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        );

        Widget mainContent = Expanded(
          flex: 3,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_showingVideo && _currentCard.videoUrl != null)
                    Expanded(
                      child: Card(
                        elevation: 10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        clipBehavior: Clip.antiAlias,
                        child: Video(controller: controller),
                      ),
                    )
                  else
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: Card(
                              elevation: 10,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              clipBehavior: Clip.antiAlias,
                              child: _currentCard.subjectId == 'Math'
                                ? Container(
                                    color: Colors.white,
                                    width: double.infinity,
                                    child: Center(
                                      child: Text(
                                        _currentCard.mathQuestion ?? '',
                                        style: const TextStyle(fontSize: 80, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                      ),
                                    ),
                                  )
                                : (_currentImages.isNotEmpty 
                                    ? (kIsWeb || _currentImages[_currentImageIndex].startsWith('http') 
                                        ? Image.network(_currentImages[_currentImageIndex], fit: BoxFit.contain)
                                        : Image.file(File(_currentImages[_currentImageIndex]), fit: BoxFit.contain))
                                    : const Icon(Icons.image_not_supported, size: 100, color: Colors.grey)),
                            ),
                          ),
                          if (_currentImages.length > 1) ...[
                            Positioned(
                              left: 20,
                              child: CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.black45,
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
                                  onPressed: () => setState(() => _currentImageIndex = (_currentImageIndex - 1 + _currentImages.length) % _currentImages.length),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 20,
                              child: CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.black45,
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right, color: Colors.white, size: 30),
                                  onPressed: () => setState(() => _currentImageIndex = (_currentImageIndex + 1) % _currentImages.length),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 20),
                  
                  if (_currentImages.length > 1)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: _currentImages.asMap().entries.map((entry) {
                          int idx = entry.key;
                          String path = entry.value;
                          bool isSelected = idx == _currentImageIndex && !_showingVideo;
                          return GestureDetector(
                            onTap: () => setState(() { _currentImageIndex = idx; _showingVideo = false; player.stop(); }),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 60, height: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isSelected ? currentSessionColor : Colors.transparent, width: 3),
                                image: DecorationImage(
                                  image: (kIsWeb || path.startsWith('http') ? NetworkImage(path) : FileImage(File(path))) as ImageProvider, 
                                  fit: BoxFit.cover
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  if (_currentCard.videoUrl != null && _currentCard.videoUrl!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final wasShowing = _showingVideo;
                          setState(() => _showingVideo = !wasShowing);
                          if (!wasShowing) {
                            if (player.state.playlist.medias.isEmpty || player.state.playlist.medias.first.uri != _currentCard.videoUrl) {
                              await player.open(Media(_currentCard.videoUrl!));
                            }
                            player.play();
                          } else {
                            player.pause();
                          }
                        },
                        icon: Icon(_showingVideo ? Icons.image : Icons.videocam),
                        label: Text(_showingVideo 
                          ? (context.t('picture') == 'picture' ? 'Picture' : context.t('picture')) 
                          : (context.t('video') == 'video' ? 'Video' : context.t('video'))),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _showingVideo ? Colors.orange : Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.digit1): () => _selectOption(0),
            const SingleActivator(LogicalKeyboardKey.digit2): () => _selectOption(1),
            const SingleActivator(LogicalKeyboardKey.digit3): () => _selectOption(2),
            const SingleActivator(LogicalKeyboardKey.digit4): () => _selectOption(3),
            const SingleActivator(LogicalKeyboardKey.digit5): () => _selectOption(4),
            const SingleActivator(LogicalKeyboardKey.digit6): () => _selectOption(5),
            const SingleActivator(LogicalKeyboardKey.enter): () { if (_isAnswered) _nextCard(); },
            const SingleActivator(LogicalKeyboardKey.numpadEnter): () { if (_isAnswered) _nextCard(); },
            const SingleActivator(LogicalKeyboardKey.space): () { if (_isAnswered) _nextCard(); },
          },
          child: Focus(
            autofocus: true,
            child: ResizeWrapper(
              child: Scaffold(
                appBar: AppBar(
                  title: DragToMoveArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: Text('${context.t('learning')}: ${TranslationService().getLanguageName(widget.languageCode)} (${_currentCard.subjectId})', style: const TextStyle(color: appBarColor)),
                    ),
                  ),
                  backgroundColor: currentSessionColor,
                  foregroundColor: appBarColor,
                  automaticallyImplyLeading: false,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.school, color: appBarColor),
                      onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SubjectPage()), (route) => false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.emoji_events, color: appBarColor),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())),
                    ),
                    IconButton(
                      icon: const Icon(Icons.style, color: appBarColor),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCardsPage())),
                    ),
                    IconButton(
                      icon: const Icon(Icons.person, color: appBarColor),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: appBarColor),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
                    ),
                    const WindowControls(color: appBarColor, iconSize: 24),
                  ],
                ),
                body: Row(
                  children: isLeft 
                    ? [sidebar, const VerticalDivider(width: 1), mainContent]
                    : [mainContent, const VerticalDivider(width: 1), sidebar],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    player.stop(); player.dispose();
    _keyboardFocus.dispose();
    super.dispose();
  }
}
