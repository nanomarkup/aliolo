import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aliolo/data/models/pillar_model.dart';

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

class _AddCardPageState extends State<AddCardPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _formKey = GlobalKey<FormState>();

  final _videoUrlController = TextEditingController();
  final Map<String, TextEditingController> _promptControllers = {};
  final Map<String, TextEditingController> _answerControllers = {};

  final List<XFile> _newImageFiles = [];
  final List<String> _existingImageUrls = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _showAllLangs = false;

  List<SubjectModel> _mySubjects = [];
  String? _selectedSubjectId;

  @override
  void initState() {
    super.initState();
    _selectedSubjectId = widget.initialSubjectId ?? widget.existingCard?.subjectId;
    _initLanguageControllers();
    _loadData();
  }

  void _initLanguageControllers() {
    final allLangs = TranslationService().availableUILanguages;
    final card = widget.existingCard;

    for (var lang in allLangs) {
      final code = lang.toLowerCase();
      _promptControllers[lang] = TextEditingController(
        text: card?.prompts[code] ?? '',
      );
      _answerControllers[lang] = TextEditingController(
        text: card?.answers[code] ?? '',
      );
    }

    if (card != null) {
      _videoUrlController.text = card.videoUrl ?? '';
      _existingImageUrls.addAll(card.imageUrls);
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final subjects = await _cardService.getManagementSubjects();
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

  @override
  void dispose() {
    _videoUrlController.dispose();
    for (var c in _promptControllers.values) {
      c.dispose();
    }
    for (var c in _answerControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _showJsonDialog() {
    final allLangs = TranslationService().availableUILanguages;
    final Map<String, String> schemaPrompts = {};
    final Map<String, String> schemaAnswers = {};

    for (var lang in allLangs) {
      final code = lang.toLowerCase();
      schemaPrompts[code] = _promptControllers[lang]?.text ?? '';
      schemaAnswers[code] = _answerControllers[lang]?.text ?? '';
    }

    final Map<String, dynamic> data = {
      'videoUrl': _videoUrlController.text,
      'prompts': schemaPrompts,
      'answers': schemaAnswers,
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
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
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
                          if (parsed['videoUrl'] != null) {
                            _videoUrlController.text =
                                parsed['videoUrl'].toString();
                          }
                          final Map? pMap = parsed['prompts'] as Map?;
                          final Map? aMap = parsed['answers'] as Map?;

                          if (pMap != null && aMap != null) {
                            // Only update languages that already exist in our controllers
                            for (var lang in _promptControllers.keys) {
                              final jsonPrompt = pMap[lang]?.toString() ?? '';
                              final jsonAnswer = aMap[lang]?.toString() ?? '';

                              final bool isPromptEmpty =
                                  jsonPrompt.trim().isEmpty;
                              final bool isAnswerEmpty =
                                  jsonAnswer.trim().isEmpty;

                              // Requirement:
                              // 1. If both empty -> update (effectively clear/delete)
                              // 2. If both non-empty -> update
                              // 3. If one is missing/empty and other is not -> ignore
                              if (isPromptEmpty == isAnswerEmpty) {
                                _promptControllers[lang]!.text = jsonPrompt;
                                _answerControllers[lang]!.text = jsonAnswer;
                              }
                            }
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

  Future<void> _pickImage({int? replaceIndex, bool? isExisting}) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && mounted) {
      setState(() {
        if (replaceIndex != null) {
          if (isExisting == true) {
            _existingImageUrls.removeAt(replaceIndex);
            _newImageFiles.insert(0, image);
          } else {
            _newImageFiles[replaceIndex] = image;
          }
        } else {
          _newImageFiles.add(image);
        }
      });
    }
  }

  void _removeNewImage(int index) {
    setState(() => _newImageFiles.removeAt(index));
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjectId == null) return;

    final Map<String, String> prompts = {};
    final Map<String, String> answers = {};

    for (var entry in _promptControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        prompts[entry.key.toLowerCase()] = entry.value.text;
      }
    }
    for (var entry in _answerControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        answers[entry.key.toLowerCase()] = entry.value.text;
      }
    }

    if (prompts.isEmpty || answers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide at least one prompt and answer.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final cardId = widget.existingCard?.id ?? _cardService.generateId();

      // Handle image uploads
      final List<String> imageUrls = List.from(_existingImageUrls);
      for (var file in _newImageFiles) {
        final url = await _cardService.uploadCardImageXFile(cardId, file);
        if (url != null) imageUrls.add(url);
      }

      final card = CardModel(
        id: cardId,
        subjectId: _selectedSubjectId!,
        level: widget.existingCard?.level ?? 1,
        prompts: prompts,
        answers: answers,
        videoUrl: _videoUrlController.text.trim().isEmpty ? null : _videoUrlController.text.trim(),
        imageUrl: imageUrls.isNotEmpty ? imageUrls.first : null,
        imageUrls: imageUrls,
        ownerId: widget.existingCard?.ownerId ?? _authService.currentUser!.serverId!,
        isPublic: widget.existingCard?.isPublic ?? false,
        isDeleted: false,
        createdAt: widget.existingCard?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _cardService.addCard(card);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving card: $e')),
        );
        setState(() => _isSaving = false);
      }
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
              _mySubjects.isNotEmpty
                  ? _mySubjects.first
                  : SubjectModel(
                    id: '',
                    names: {'en': '...'},
                    pillarId: 1,
                    descriptions: {},
                    ownerId: '',
                    isPublic: false,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
    );

    final pillar = pillars.firstWhere(
      (p) => p.id == (widget.pillarId ?? selectedSubject.pillarId),
      orElse: () => pillars.first,
    );
    final currentSessionColor = pillar.getColor();
    const appBarColor = Colors.white;

    String titleKey = 'add_card';
    if (widget.existingCard != null) {
      titleKey = widget.isReadOnly ? 'view_card' : 'edit_card';
    }

    return AlioloScrollablePage(
      title: Text(
        context.t(titleKey),
        style: const TextStyle(color: appBarColor),
      ),
      appBarColor: currentSessionColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
        IconButton(
          icon: const Text(
            '{}',
            style: TextStyle(
              color: appBarColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
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
                if (mounted) {
                  Navigator.pop(context, true);
                }
              }
            },
          ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _buildSectionCaption(context.t('video')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _videoUrlController,
              decoration: InputDecoration(
                labelText: context.t('video_url_optional'),
                border: const OutlineInputBorder(),
              ),
              enabled: !widget.isReadOnly,
            ),
            const SizedBox(height: 24),
            _buildImageSection(currentSessionColor),
            const SizedBox(height: 24),
            _buildSectionCaption(context.t('prompts_answers')),
            const SizedBox(height: 12),
            ..._promptControllers.keys
                .where(
                  (lang) =>
                      _showAllLangs ||
                      lang == 'en' ||
                      _promptControllers[lang]!.text.isNotEmpty,
                )
                .map(
                  (lang) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Tooltip(
                          message: TranslationService().getLanguageName(lang),
                          child: SizedBox(
                            width: 40,
                            child: Text(
                              lang.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextFormField(
                            controller: _promptControllers[lang],
                            decoration: InputDecoration(labelText: context.t('prompt_label')),
                            enabled: !widget.isReadOnly,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _answerControllers[lang],
                            decoration: InputDecoration(labelText: context.t('answer')),
                            enabled: !widget.isReadOnly,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            TextButton(
              onPressed: () => setState(() => _showAllLangs = !_showAllLangs),
              child: Text(
                _showAllLangs
                    ? context.t('show_less_languages')
                    : context.t('show_all_languages'),
              ),
            ),
            const SizedBox(height: 32),
            if (!widget.isReadOnly)
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                  backgroundColor: currentSessionColor,
                  foregroundColor: Colors.white,
                ),
                child:
                    _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                          context.t('save_card'),
                          style: const TextStyle(fontSize: 18),
                        ),
              ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCaption(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildImageSection(Color themeColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionCaption(context.t('images')),
            if (!widget.isReadOnly)
              IconButton(
                icon: Icon(Icons.add_a_photo, color: themeColor),
                onPressed: () => _pickImage(),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_existingImageUrls.isEmpty && _newImageFiles.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('No images added', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          SizedBox(
            height: 140,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ..._existingImageUrls.asMap().entries.map(
                  (entry) => _buildImageThumbnail(
                    imageUrl: entry.value,
                    onRemove: () => _removeExistingImage(entry.key),
                    onReplace:
                        () => _pickImage(replaceIndex: entry.key, isExisting: true),
                  ),
                ),
                ..._newImageFiles.asMap().entries.map(
                  (entry) => _buildImageThumbnail(
                    file: entry.value,
                    onRemove: () => _removeNewImage(entry.key),
                    onReplace:
                        () => _pickImage(replaceIndex: entry.key, isExisting: false),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildImageThumbnail({
    String? imageUrl,
    XFile? file,
    required VoidCallback onRemove,
    required VoidCallback onReplace,
  }) {
    if (file == null && imageUrl == null) return const SizedBox.shrink();

    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(imageUrl, fit: BoxFit.cover)
          else if (file != null)
            kIsWeb
                ? Image.network(file.path, fit: BoxFit.cover)
                : Image.file(File(file.path), fit: BoxFit.cover),
          if (!widget.isReadOnly)
            Positioned(
              top: 4,
              right: 4,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onReplace,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
