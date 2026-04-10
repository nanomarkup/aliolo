import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/sound_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

import 'package:aliolo/features/feedback/presentation/pages/feedback_page.dart';
import 'package:aliolo/features/settings/presentation/pages/premium_upgrade_page.dart';

class AddCardPage extends StatefulWidget {
  final String? initialSubjectId;
  final int? pillarId;
  final CardModel? existingCard;
  final bool isReadOnly;

  const AddCardPage({
    super.key,
    this.initialSubjectId,
    this.pillarId,
    this.existingCard,
    this.isReadOnly = false,
  });

  @override
  State<AddCardPage> createState() => _AddCardPageState();
}

class DraftLocalizedData {
  String prompt = '';
  String answer = '';
  String? audioUrl;
  XFile? newAudioFile;
  String? videoUrl;
  XFile? newVideoFile;
  List<String> imageUrls = [];
  List<XFile> newImageFiles = [];
  Map<String, dynamic> rawData = {};
  List<String> deletedUrls = [];

  DraftLocalizedData();

  factory DraftLocalizedData.fromModel(LocalizedCardData data) {
    final d = DraftLocalizedData();
    d.prompt = data.prompt ?? '';
    d.answer = data.answer ?? '';
    d.audioUrl = data.audioUrl;
    d.videoUrl = data.videoUrl;
    d.imageUrls = List.from(data.imageUrls ?? []);
    d.rawData = Map.from(data.rawData);
    return d;
  }

  Map<String, dynamic> toJson() {
    return {
      'prompt': prompt,
      'answer': answer,
      'audio_url': audioUrl ?? '',
      'video_url': videoUrl ?? '',
      'image_urls': imageUrls,
    };
  }
}

class _AddCardPageState extends State<AddCardPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _imagePicker = ImagePicker();

  final _promptController = TextEditingController();
  final _answerController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _showSidebar = false;
  String _selectedLang = 'global';
  int _cardLevel = 1;
  String _testMode = 'image_to_text';
  int _itemsPerRow = 8;

  final Map<String, DraftLocalizedData> _drafts = {
    'global': DraftLocalizedData(),
  };

  List<SubjectModel> _mySubjects = [];
  String? _selectedSubjectId;
  int? _internalPillarId;
  final _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSidebarState();

    // Premium Locking: Redirect if creating new and not premium
    if (widget.existingCard == null) {
      final sub = getIt<SubscriptionService>();
      if (!sub.isPremium) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const PremiumUpgradePage())
            );
          }
        });
      }
    }

    _selectedSubjectId =
        widget.initialSubjectId ?? widget.existingCard?.subjectId;
    _internalPillarId = widget.pillarId;
    _initDrafts();
    _loadData();
    _updateControllers();
  }

  Future<void> _loadSidebarState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showSidebar = prefs.getBool('show_localization_sidebar') ?? false;
      });
    }
  }

  Future<void> _toggleSidebar() async {
    final newState = !_showSidebar;
    setState(() => _showSidebar = newState);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_localization_sidebar', newState);
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final sortedLangs = TranslationService()
        .availableUILanguages
        .map((l) => l.toLowerCase())
        .toList();
    sortedLangs.sort();

    final availableLangs = [
      'global',
      ...sortedLangs,
    ];
    final currentIndex = availableLangs.indexOf(_selectedLang);
    if (currentIndex == -1) return;

    int? newIndex;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      newIndex = (currentIndex + 1) % availableLangs.length;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      newIndex =
          (currentIndex - 1 + availableLangs.length) % availableLangs.length;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      newIndex = currentIndex + _itemsPerRow;
      if (newIndex >= availableLangs.length) {
        newIndex = currentIndex % _itemsPerRow;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      newIndex = currentIndex - _itemsPerRow;
      if (newIndex < 0) {
        int lastRowStart =
            ((availableLangs.length - 1) ~/ _itemsPerRow) * _itemsPerRow;
        newIndex = lastRowStart + currentIndex;
        if (newIndex >= availableLangs.length) newIndex -= _itemsPerRow;
      }
    }

    if (newIndex != null) {
      setState(() {
        _selectedLang = availableLangs[newIndex!];
        _updateControllers();
      });
    }
  }

  void _initDrafts() {
    if (widget.existingCard != null) {
      _cardLevel = widget.existingCard!.level;
      _testMode = widget.existingCard!.testMode;
      widget.existingCard!.localizedData.forEach((lang, data) {
        _drafts[lang] = DraftLocalizedData.fromModel(data);
      });
    }
  }

  void _ensureDraftExists(String lang) {
    if (!_drafts.containsKey(lang)) {
      _drafts[lang] = DraftLocalizedData();
    }
  }

  void _updateControllers() {
    _ensureDraftExists(_selectedLang);
    final draft = _drafts[_selectedLang]!;
    _promptController.text = draft.prompt;
    _answerController.text = draft.answer;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _answerController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final subjects = await _cardService.getDashboardSubjects();
    final myId = _authService.currentUser?.serverId;
    if (mounted) {
      setState(() {
        _mySubjects = subjects.where((s) => s.ownerId == myId).toList();
        if (_selectedSubjectId == null && _mySubjects.isNotEmpty) {
          _selectedSubjectId = _mySubjects.first.id;
        }

        // Try to find the pillarId if we don't have it
        if (_internalPillarId == null && _selectedSubjectId != null) {
          final s = subjects.firstWhere(
            (s) => s.id == _selectedSubjectId,
            orElse: () => subjects.firstWhere((s) => true), // just a dummy or keep null
          );
          if (s.id == _selectedSubjectId) {
            _internalPillarId = s.pillarId;
          }
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null &&
        (result.files.single.path != null ||
            (kIsWeb && result.files.single.bytes != null))) {
      final file = result.files.single;
      if (file.size > 5 * 1024 * 1024) {
        _showError('${context.t('file_too_large')} (Max 5MB)');
        return;
      }
      setState(() {
        _ensureDraftExists(_selectedLang);
        _drafts[_selectedLang]!.newImageFiles.add(
          XFile(file.path ?? '', bytes: file.bytes, name: file.name),
        );
      });
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null &&
        (result.files.single.path != null ||
            (kIsWeb && result.files.single.bytes != null))) {
      final file = result.files.single;
      if (file.size > 10 * 1024 * 1024) {
        _showError('${context.t('file_too_large')} (Max 10MB)');
        return;
      }
      setState(() {
        _ensureDraftExists(_selectedLang);
        _drafts[_selectedLang]!.newAudioFile = XFile(
          file.path ?? '',
          bytes: file.bytes,
          name: file.name,
        );
      });
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result != null &&
        (result.files.single.path != null ||
            (kIsWeb && result.files.single.bytes != null))) {
      final file = result.files.single;
      if (file.size > 50 * 1024 * 1024) {
        _showError('${context.t('file_too_large')} (Max 50MB)');
        return;
      }
      setState(() {
        _ensureDraftExists(_selectedLang);
        _drafts[_selectedLang]!.newVideoFile = XFile(
          file.path ?? '',
          bytes: file.bytes,
          name: file.name,
        );
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _playUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    
    // If it's an audio file, use SoundService to play it in-app
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.endsWith('.mp3') || lowerUrl.endsWith('.wav') || lowerUrl.endsWith('.m4a')) {
      await SoundService().playUrl(url);
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showError('Could not launch $url');
    }
  }

  String _getFileName(String? url, XFile? file) {
    if (file != null) return file.name;
    if (url != null && url.isNotEmpty) {
      try {
        return p.basename(Uri.parse(url).path);
      } catch (_) {
        return 'file';
      }
    }
    return '';
  }

  void _showJsonDialog() {
    final Map<String, dynamic> data = _drafts.map(
      (key, value) => MapEntry(key, {
        'prompt': value.prompt,
        'answer': value.answer,
      }),
    );

    final encoder = const JsonEncoder.withIndent('  ');
    final String jsonTemplate = encoder.convert(data);
    final textController = TextEditingController(text: jsonTemplate);

    showDialog(
      context: context,
      builder: (context) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            final content = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: TextField(
                    controller: textController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.all(12),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                            ClipboardData(text: textController.text),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.t('info_copied')),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(context.t('copy')),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (data?.text != null) {
                            textController.text = data!.text!;
                          }
                        },
                        icon: const Icon(Icons.paste, size: 18),
                        label: Text(context.t('paste')),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          try {
                            final Map<String, dynamic> parsed = jsonDecode(
                              textController.text,
                            );
                            setState(() {
                              parsed.forEach((lang, val) {
                                final l = lang.toString().toLowerCase();
                                _ensureDraftExists(l);
                                if (val is Map) {
                                  final d = val as Map<String, dynamic>;
                                  if (d.containsKey('prompt')) {
                                    _drafts[l]!.prompt = d['prompt']?.toString() ?? '';
                                  }
                                  if (d.containsKey('answer')) {
                                    _drafts[l]!.answer = d['answer']?.toString() ?? '';
                                  }
                                }
                              });
                              _updateControllers();
                            });
                            Navigator.pop(context);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Invalid JSON: $e')),
                            );
                          }
                        },
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(context.t('update')),
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (isMobile) {
              return Dialog.fullscreen(
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('Localized Data'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  body: Padding(
                    padding: const EdgeInsets.all(16),
                    child: content,
                  ),
                ),
              );
            }

            return AlertDialog(
              title: Row(
                children: [
                  const Text('Localized Data'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
                child: content,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _save() async {
    if (_selectedSubjectId == null) return;
    setState(() => _isSaving = true);

    try {
      final cardId = widget.existingCard?.id ?? _cardService.generateId();
      final Map<String, LocalizedCardData> finalData = {};

      for (var entry in _drafts.entries) {
        final lang = entry.key;
        final draft = entry.value;

        bool hasContent =
            draft.prompt.isNotEmpty ||
            draft.answer.isNotEmpty ||
            draft.newAudioFile != null ||
            draft.audioUrl != null ||
            draft.imageUrls.isNotEmpty ||
            draft.newImageFiles.isNotEmpty ||
            draft.newVideoFile != null ||
            draft.videoUrl != null;

        if (lang != 'global' && !hasContent) {
          continue;
        }

        final List<String> imageUrls = List.from(draft.imageUrls);
        for (var file in draft.newImageFiles) {
          final url = await _cardService.uploadCardImage(cardId, file, lang);
          if (url != null) {
            imageUrls.add(url);
          } else {
            throw Exception(
              'Failed to upload image. Please check your internet connection and Supabase storage buckets (card_images).',
            );
          }
        }

        String? audioUrl = draft.audioUrl;
        if (draft.newAudioFile != null) {
          if (draft.audioUrl != null) draft.deletedUrls.add(draft.audioUrl!);
          audioUrl = await _cardService.uploadCardAudio(
            cardId,
            draft.newAudioFile!,
            lang,
          );
          if (audioUrl == null) {
            throw Exception(
              'Failed to upload audio. Please check your internet connection and Supabase storage buckets (card_audio).',
            );
          }
        }

        String? videoUrl = draft.videoUrl;
        if (draft.newVideoFile != null) {
          if (draft.videoUrl != null) draft.deletedUrls.add(draft.videoUrl!);
          videoUrl = await _cardService.uploadCardVideo(
            cardId,
            draft.newVideoFile!,
            lang,
          );
          if (videoUrl == null) {
            throw Exception(
              'Failed to upload video. Please check your internet connection and Supabase storage buckets (card_videos).',
            );
          }
        }

        // Cleanup storage for explicitly removed or replaced files
        for (var url in draft.deletedUrls) {
          String bucket = 'card_images';
          if (url.contains('/card_audio/')) {
            bucket = 'card_audio';
          } else if (url.contains('/card_videos/')) {
            bucket = 'card_videos';
          }
          await _cardService.deleteCardMediaFile(bucket, url);
        }
        draft.deletedUrls.clear();

        finalData[lang] = LocalizedCardData(
          prompt: draft.prompt.isEmpty ? null : draft.prompt,
          answer: draft.answer.isEmpty ? null : draft.answer,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          imageUrls: imageUrls.isEmpty ? null : imageUrls,
          rawData: draft.rawData,
        );
      }

      final card = CardModel(
        id: cardId,
        subjectId: _selectedSubjectId!,
        level: _cardLevel,
        testMode: _testMode,
        ownerId: _authService.currentUser!.serverId!,
        isPublic: widget.existingCard?.isPublic ?? false,
        createdAt: widget.existingCard?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        localizedData: finalData,
      );

      await _cardService.addCard(card);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Error saving card: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myId = _authService.currentUser?.serverId;
    final isOwner = widget.existingCard == null || widget.existingCard!.ownerId == myId;

    if (!isOwner) {
      return Scaffold(
        appBar: AppBar(title: Text(context.t('view_card'))),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('You do not have permission to view this card details.', textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final selectedSubject = _mySubjects.firstWhere(
      (s) => s.id == _selectedSubjectId,
      orElse:
          () =>
              _mySubjects.isNotEmpty ? _mySubjects.first : SubjectModel.empty(),
    );

    final pillar = pillars.firstWhere(
      (p) => p.id == (widget.pillarId ?? selectedSubject.pillarId),
      orElse: () => pillars.first,
    );
    final themeService = getIt<ThemeService>();
    final themeColor = pillar.getColor(themeService.isDarkMode);
    const appBarColor = Colors.white;

    final String pageTitle =
        widget.isReadOnly
            ? context.t('view_card')
            : (widget.existingCard == null
                ? context.t('add_card')
                : context.t('edit_card'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 600;

        final backAction = IconButton(
          tooltip: context.t('back'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        );

        final saveAction = !widget.isReadOnly
            ? IconButton(
              tooltip: context.t('save'),
              icon: _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: appBarColor,
                      strokeWidth: 2,
                    ),
                  )
                  : const Icon(Icons.save),
              onPressed: _isSaving ? null : _save,
            )
            : null;

        final jsonAction = !widget.isReadOnly
            ? IconButton(
              tooltip: 'JSON',
              icon: const Icon(Icons.data_object),
              onPressed: _showJsonDialog,
            )
            : null;

        final deleteAction = (widget.existingCard != null && !widget.isReadOnly)
            ? IconButton(
              tooltip: context.t('delete'),
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: Text(context.t('delete')),
                        content: Text(context.t('delete_card_confirm')),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.t('cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(context.t('confirm')),
                          ),
                        ],
                      ),
                );
                if (confirmed == true && mounted) {
                  await _cardService.deleteCard(widget.existingCard!);
                  if (mounted) Navigator.pop(context, true);
                }
              },
            )
            : null;

        final feedbackAction = (widget.existingCard != null)
            ? IconButton(
              tooltip: context.t('feedback'),
              icon: const Icon(Icons.feedback),
              onPressed: () {
                final pillar = pillars.firstWhere(
                  (p) => p.id == (_internalPillarId ?? 1),
                  orElse: () => pillars.first,
                );
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => FeedbackPage(
                          subjectId: widget.existingCard?.subjectId ?? widget.initialSubjectId,
                          cardId: widget.existingCard?.id,
                          contextTitle: widget.existingCard != null 
                            ? 'Card: ${widget.existingCard!.localizedData['global']?.answer}'
                            : 'Card',
                          appBarColor: pillar.getColor(themeService.isDarkMode),
                        ),
                  ),
                );
              },
            )
            : null;

        return AlioloScrollablePage(
          title: Text(pageTitle, style: const TextStyle(color: appBarColor)),
          appBarColor: themeColor,
          actions: isSmallScreen 
              ? [
                  backAction,
                  if (saveAction != null) saveAction,
                  IconButton(
                    tooltip: context.t('languages') ?? 'Languages',
                    icon: Icon(_showSidebar ? Icons.last_page : Icons.language),
                    onPressed: _toggleSidebar,
                  ),
                ]
              : [
                  backAction,
                  if (saveAction != null) saveAction,
                  if (jsonAction != null) jsonAction,
                  if (deleteAction != null) deleteAction,
                  if (feedbackAction != null) feedbackAction,
                  IconButton(
                    tooltip: context.t('languages') ?? 'Languages',
                    icon: Icon(_showSidebar ? Icons.last_page : Icons.language),
                    onPressed: _toggleSidebar,
                  ),
                ],
          overflowActions: isSmallScreen
              ? [
                  if (jsonAction != null) jsonAction,
                  if (deleteAction != null) deleteAction,
                  if (feedbackAction != null) feedbackAction,
                ]
              : null,
          body: KeyboardListener(
        focusNode: _keyboardFocusNode,
        autofocus: true,
        onKeyEvent: _onKeyEvent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_showSidebar && isSmallScreen)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: _buildLangGrid(),
                        ),
                      const SizedBox(height: 16),
                      _buildEditor(themeColor),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
            if (_showSidebar && !isSmallScreen)
              Container(
                width: 320,
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: Theme.of(context).dividerColor,
                    ),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildLangGrid(),
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
  Widget _buildLangTile(
    String code,
    String label,
    IconData? icon,
    String tooltip,
  ) {
    final isSelected = _selectedLang == code;
    final draft = _drafts[code];
    final hasData =
        draft != null &&
        (draft.prompt.isNotEmpty ||
            draft.answer.isNotEmpty ||
            draft.newImageFiles.isNotEmpty ||
            draft.imageUrls.isNotEmpty ||
            draft.newAudioFile != null ||
            draft.audioUrl != null);

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLang = code;
            _updateControllers();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color:
                isSelected
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Theme.of(context).cardColor,
            border: Border.all(
              color:
                  isSelected
                      ? Colors.orange
                      : Colors.grey.withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (icon != null)
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.orange : Colors.grey,
                )
              else
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected || hasData
                            ? FontWeight.bold
                            : FontWeight.normal,
                    color:
                        isSelected
                            ? Colors.orange
                            : (hasData ? null : Colors.grey),
                  ),
                ),
              if (hasData && !isSelected)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(Color color) {
    _ensureDraftExists(_selectedLang);
    final draft = _drafts[_selectedLang]!;
    final isGlobal = _selectedLang == 'global';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isGlobal) ...[
          _buildSectionCaption(context.t('common_settings')),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              if (isSmall) {
                return Column(
                  children: [
                    _buildSubjectPicker(),
                    const SizedBox(height: 16),
                    _buildTestModePicker(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildSubjectPicker()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTestModePicker()),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _buildLevelPicker(color),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 32),
        ],
        _buildSectionCaption(
          context.t(
            'content_label',
            args: {'lang': _selectedLang.toUpperCase()},
          ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _promptController,
          onChanged: (v) => draft.prompt = v,
          decoration: InputDecoration(
            labelText: context.t('prompt_label'),
            border: const OutlineInputBorder(),
          ),
          maxLines: 1,
          enabled: !widget.isReadOnly,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _answerController,
          onChanged: (v) => draft.answer = v,
          decoration: InputDecoration(
            labelText: context.t('answer'),
            border: const OutlineInputBorder(),
          ),
          enabled: !widget.isReadOnly,
        ),
        const SizedBox(height: 32),
        _buildMediaSection(
          context.t('images'),
          Icons.image,
          _pickImage,
          _buildImageList(draft),
        ),
        const SizedBox(height: 24),
        _buildMediaSection(
          context.t('audio'),
          Icons.audiotrack,
          _pickAudio,
          _buildAudioPreview(draft),
        ),
        const SizedBox(height: 24),
        _buildMediaSection(
          context.t('video'),
          Icons.videocam,
          _pickVideo,
          _buildVideoPreview(draft),
        ),
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionCaption(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSubjectPicker() {
    // Ensure the current subject ID is in the list to avoid dropdown assertion error
    final List<DropdownMenuItem<String>> items =
        _mySubjects
            .map(
              (s) => DropdownMenuItem(
                value: s.id,
                child: Text(
                  s.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList();

    if (_selectedSubjectId != null &&
        !_mySubjects.any((s) => s.id == _selectedSubjectId)) {
      items.add(
        DropdownMenuItem(
          value: _selectedSubjectId,
          child: const Text(
            'Public/Other Subject',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedSubjectId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.t('subject_label'),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items,
      onChanged:
          widget.isReadOnly
              ? null
              : (v) => setState(() => _selectedSubjectId = v),
    );
  }

  Widget _buildTestModePicker() {
    return DropdownButtonFormField<String>(
      value: _testMode,
      decoration: InputDecoration(
        labelText: context.t('test_mode_label'),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: [
        DropdownMenuItem(
          value: 'image_to_text',
          child: Text(context.t('mode_image_to_text')),
        ),
        DropdownMenuItem(
          value: 'audio_to_text',
          child: Text(context.t('mode_audio_to_text')),
        ),
        DropdownMenuItem(
          value: 'audio_to_image',
          child: Text(context.t('mode_audio_to_image')),
        ),
        DropdownMenuItem(
          value: 'text_to_text',
          child: Text(context.t('mode_text_to_text')),
        ),
      ],
      onChanged:
          widget.isReadOnly
              ? null
              : (v) => setState(() => _testMode = v ?? 'image_to_text'),
    );
  }

  Widget _buildLevelPicker(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('card_level', args: {'level': '$_cardLevel'}),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Text(
                '$_cardLevel',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              child: Slider(
                value: _cardLevel.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                label: '$_cardLevel',
                activeColor: color,
                onChanged:
                    widget.isReadOnly
                        ? null
                        : (v) => setState(() => _cardLevel = v.round()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMediaSection(
    String title,
    IconData icon,
    VoidCallback onAdd,
    Widget content,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const Spacer(),
            if (!widget.isReadOnly)
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: onAdd,
                color: Colors.orange,
              ),
          ],
        ),
        content,
      ],
    );
  }

  Widget _buildImageList(DraftLocalizedData draft) {
    if (draft.imageUrls.isEmpty && draft.newImageFiles.isEmpty) {
      return Text(
        _selectedLang == 'global'
            ? context.t('no_images_added')
            : context.t('no_localized_images'),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return SizedBox(
      height: 80,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ...draft.imageUrls.map(
            (url) => _buildThumbnail(
              url: url,
              onRemove: () => setState(() {
                draft.imageUrls.remove(url);
                draft.deletedUrls.add(url);
              }),
            ),
          ),
          ...draft.newImageFiles.map(
            (file) => _buildThumbnail(
              file: file,
              onRemove: () => setState(() => draft.newImageFiles.remove(file)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail({
    String? url,
    XFile? file,
    required VoidCallback onRemove,
  }) {
    return Container(
      width: 70,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (url != null)
            Image.network(url, fit: BoxFit.cover, width: 70, height: 70)
          else if (file != null)
            kIsWeb
                ? (file.path.isNotEmpty
                    ? Image.network(file.path, fit: BoxFit.cover)
                    : const Icon(Icons.image, color: Colors.grey))
                : Image.file(dynamicFile(file.path), fit: BoxFit.cover),
          if (!widget.isReadOnly)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  color: Colors.black54,
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAudioPreview(DraftLocalizedData draft) {
    if ((draft.audioUrl == null || draft.audioUrl!.isEmpty) &&
        draft.newAudioFile == null) {
      return Text(
        context.t('no_localized_audio'),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: const Icon(Icons.audiotrack, color: Colors.orange, size: 18),
      title: Text(
        _getFileName(draft.audioUrl, draft.newAudioFile),
        style: const TextStyle(fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (draft.audioUrl != null)
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 18, color: Colors.blue),
              onPressed: () => _playUrl(draft.audioUrl),
              tooltip: 'Play',
            ),
          if (!widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.delete, size: 16),
              onPressed: () => setState(() {
                if (draft.audioUrl != null) {
                  draft.deletedUrls.add(draft.audioUrl!);
                }
                draft.audioUrl = null;
                draft.newAudioFile = null;
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPreview(DraftLocalizedData draft) {
    if ((draft.videoUrl == null || draft.videoUrl!.isEmpty) &&
        draft.newVideoFile == null) {
      return Text(
        context.t('no_localized_video'),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: const Icon(Icons.videocam, color: Colors.orange, size: 18),
      title: Text(
        _getFileName(draft.videoUrl, draft.newVideoFile),
        style: const TextStyle(fontSize: 13),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (draft.videoUrl != null)
            IconButton(
              icon: const Icon(Icons.play_arrow, size: 18, color: Colors.blue),
              onPressed: () => _playUrl(draft.videoUrl),
              tooltip: 'Play',
            ),
          if (!widget.isReadOnly)
            IconButton(
              icon: const Icon(Icons.delete, size: 16),
              onPressed: () => setState(() {
                if (draft.videoUrl != null) {
                  draft.deletedUrls.add(draft.videoUrl!);
                }
                draft.videoUrl = null;
                draft.newVideoFile = null;
              }),
            ),
        ],
      ),
    );
  }


  Widget _buildLangGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final items = (availableWidth + 8) ~/ 62;
        _itemsPerRow = items > 0 ? items : 1;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildLangTile(
              'global',
              'GLB',
              Icons.public,
              'Global / Fallback',
            ),
            ...(() {
              final langs = TranslationService()
                  .availableUILanguages
                  .map((l) => l.toLowerCase())
                  .toList();
              langs.sort();
              return langs.map((code) {
                return _buildLangTile(
                  code,
                  code.toUpperCase(),
                  null,
                  TranslationService().getLanguageName(code),
                );
              });
            })(),
          ],
        );
      },
    );
  }
}
