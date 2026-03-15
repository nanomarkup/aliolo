import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:flutter/foundation.dart';

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

  DraftLocalizedData();

  factory DraftLocalizedData.fromModel(LocalizedCardData data) {
    final d = DraftLocalizedData();
    d.prompt = data.prompt ?? '';
    d.answer = data.answer ?? '';
    d.audioUrl = data.audioUrl;
    d.videoUrl = data.videoUrl;
    d.imageUrls = List.from(data.imageUrls ?? []);
    return d;
  }

  Map<String, dynamic> toJson() {
    return {
      if (prompt.isNotEmpty) 'prompt': prompt,
      if (answer.isNotEmpty) 'answer': answer,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (videoUrl != null) 'video_url': videoUrl,
      if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
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
  String _selectedLang = 'global';
  int _cardLevel = 1;
  String _testMode = 'image_to_text';

  final Map<String, DraftLocalizedData> _drafts = {
    'global': DraftLocalizedData(),
  };

  List<SubjectModel> _mySubjects = [];
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId =
        widget.initialSubjectId ?? widget.existingCard?.subjectId;
    _initDrafts();
    _loadData();
    _updateControllers();
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

  void _showJsonDialog() {
    final Map<String, dynamic> data = {
      'subjectId': _selectedSubjectId,
      'testMode': _testMode,
      'level': _cardLevel,
      'localizedData': _drafts.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };

    final encoder = const JsonEncoder.withIndent('  ');
    final String jsonTemplate = encoder.convert(data);
    final textController = TextEditingController(text: jsonTemplate);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('JSON Data'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
              child: Column(
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
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            actions: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Clipboard.setData(
                        ClipboardData(text: textController.text),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('COPY'),
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
                    label: const Text('PASTE'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      try {
                        final Map<String, dynamic> parsed = jsonDecode(
                          textController.text,
                        );
                        setState(() {
                          if (parsed['subjectId'] is String) {
                            _selectedSubjectId = parsed['subjectId'];
                          }
                          if (parsed['testMode'] is String) {
                            _testMode = parsed['testMode'];
                          }
                          if (parsed['level'] is int) {
                            _cardLevel = parsed['level'];
                          }
                          if (parsed['localizedData'] is Map) {
                            final locData = parsed['localizedData'] as Map;
                            locData.forEach((lang, val) {
                              final l = lang.toString().toLowerCase();
                              _ensureDraftExists(l);
                              final d = val as Map<String, dynamic>;
                              _drafts[l]!.prompt = d['prompt'] ?? '';
                              _drafts[l]!.answer = d['answer'] ?? '';
                              _drafts[l]!.audioUrl = d['audio_url'];
                              _drafts[l]!.videoUrl = d['video_url'];
                              if (d['image_urls'] != null) {
                                _drafts[l]!.imageUrls = List<String>.from(
                                  d['image_urls'],
                                );
                              }
                            });
                            _updateControllers();
                          }
                        });
                        Navigator.pop(context);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Invalid JSON: $e')),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('UPDATE'),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, size: 18),
                    label: Text(context.t('cancel').toUpperCase()),
                  ),
                ],
              ),
            ],
          ),
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

        finalData[lang] = LocalizedCardData(
          prompt: draft.prompt.isEmpty ? null : draft.prompt,
          answer: draft.answer.isEmpty ? null : draft.answer,
          audioUrl: audioUrl,
          videoUrl: videoUrl,
          imageUrls: imageUrls.isEmpty ? null : imageUrls,
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
    final themeColor = pillar.getColor();
    const appBarColor = Colors.white;

    final String pageTitle =
        widget.isReadOnly
            ? 'View Card'
            : (widget.existingCard == null
                ? context.t('add_card')
                : context.t('edit_card'));

    return AlioloScrollablePage(
      title: Text(pageTitle, style: const TextStyle(color: appBarColor)),
      appBarColor: themeColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
        if (!widget.isReadOnly)
          IconButton(
            icon:
                _isSaving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: appBarColor,
                        strokeWidth: 2,
                      ),
                    )
                    : const Icon(Icons.save, color: appBarColor),
            onPressed: _isSaving ? null : _save,
          ),
        if (!widget.isReadOnly)
          IconButton(
            icon: const Icon(Icons.data_object, color: appBarColor),
            onPressed: _showJsonDialog,
          ),
        if (widget.existingCard != null && !widget.isReadOnly)
          IconButton(
            icon: const Icon(Icons.delete, color: appBarColor),
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
          ),
      ],
      fixedBody: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildLangTile(
                  'global',
                  'GLB',
                  Icons.public,
                  'Global / Fallback',
                ),
                ...TranslationService().availableUILanguages.map((lang) {
                  final code = lang.toLowerCase();
                  return _buildLangTile(
                    code,
                    lang.toUpperCase(),
                    null,
                    TranslationService().getLanguageName(code),
                  );
                }),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: _buildEditor(themeColor),
      ),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSubjectPicker()),
              const SizedBox(width: 16),
              Expanded(child: _buildTestModePicker()),
            ],
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
          maxLines: 2,
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
    return DropdownButtonFormField<String>(
      value: _selectedSubjectId,
      decoration: InputDecoration(
        labelText: context.t('subject_label'),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items:
          _mySubjects
              .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
              .toList(),
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
          child: Text(context.t('image_to_text')),
        ),
        DropdownMenuItem(
          value: 'audio_to_text',
          child: Text(context.t('audio_to_text')),
        ),
        DropdownMenuItem(
          value: 'audio_to_image',
          child: Text(context.t('audio_to_image')),
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
        Slider(
          value: _cardLevel.toDouble(),
          min: 1,
          max: 20,
          divisions: 19,
          activeColor: color,
          onChanged:
              widget.isReadOnly
                  ? null
                  : (v) => setState(() => _cardLevel = v.round()),
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
              onRemove: () => setState(() => draft.imageUrls.remove(url)),
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
                ? Image.network(file.path, fit: BoxFit.cover)
                : Image.file(File(file.path), fit: BoxFit.cover),
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
        draft.newAudioFile?.name ?? context.t('uploaded_audio'),
        style: const TextStyle(fontSize: 13),
      ),
      trailing:
          widget.isReadOnly
              ? null
              : IconButton(
                icon: const Icon(Icons.delete, size: 16),
                onPressed:
                    () => setState(() {
                      draft.audioUrl = null;
                      draft.newAudioFile = null;
                    }),
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
        draft.newVideoFile?.name ?? context.t('uploaded_video'),
        style: const TextStyle(fontSize: 13),
      ),
      trailing:
          widget.isReadOnly
              ? null
              : IconButton(
                icon: const Icon(Icons.delete, size: 16),
                onPressed:
                    () => setState(() {
                      draft.videoUrl = null;
                      draft.newVideoFile = null;
                    }),
              ),
    );
  }
}
