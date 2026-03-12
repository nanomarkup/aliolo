import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:window_manager/window_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/core/utils/logger.dart';

class AddCardPage extends StatefulWidget {
  final CardModel? existingCard;
  final int? pillarId;
  final String? initialSubjectId;
  final bool isReadOnly;

  const AddCardPage({
    super.key,
    this.existingCard,
    this.pillarId,
    this.initialSubjectId,
    this.isReadOnly = false,
  });

  @override
  State<AddCardPage> createState() => _AddCardPageState();
}

class _AddCardPageState extends State<AddCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _imagePicker = ImagePicker();

  late TextEditingController _videoUrlController;
  late TextEditingController _levelController;
  String? _selectedSubjectId;
  int? _selectedPillar;
  bool _showAllLangs = false;
  bool _isSaving = false;

  final Map<String, TextEditingController> _promptControllers = {};
  final Map<String, TextEditingController> _answerControllers = {};

  List<SubjectModel> _mySubjects = [];
  bool _isLoading = true;

  // Image management
  List<String> _existingImageUrls = [];
  final List<XFile?> _newImageFiles = [];

  @override
  void initState() {
    super.initState();
    _videoUrlController = TextEditingController(
      text: widget.existingCard?.videoUrl ?? '',
    );
    _levelController = TextEditingController(
      text: widget.existingCard?.level.toString() ?? '1',
    );
    _selectedPillar = widget.pillarId ?? pillars.first.id;
    _selectedSubjectId =
        widget.initialSubjectId ?? widget.existingCard?.subjectId;
    _existingImageUrls = List<String>.from(
      widget.existingCard?.imageUrls ?? [],
    );

    _initLanguageControllers();
    _loadSubjects();
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
  }

  Future<void> _loadSubjects() async {
    final subjects = await _cardService.getDashboardSubjects();
    setState(() {
      _mySubjects = subjects;
      if (_selectedSubjectId != null) {
        final subject = _mySubjects.firstWhere(
          (s) => s.id == _selectedSubjectId,
          orElse: () => _mySubjects.first,
        );
        _selectedPillar = subject.pillarId;
      } else if (_mySubjects.isNotEmpty) {
        final inPillar =
            _mySubjects.where((s) => s.pillarId == _selectedPillar).toList();
        if (inPillar.isNotEmpty) {
          _selectedSubjectId = inPillar.first.id;
        } else {
          _selectedSubjectId = _mySubjects.first.id;
          _selectedPillar = _mySubjects.first.pillarId;
        }
      }
      _isLoading = false;
    });
  }

  Future<void> _pickImage({int? replaceIndex, bool isExisting = false}) async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (image == null) return;

    setState(() {
      if (replaceIndex != null) {
        if (isExisting) {
          _existingImageUrls.removeAt(replaceIndex);
          _newImageFiles.add(image);
        } else {
          _newImageFiles[replaceIndex] = image;
        }
      } else {
        _newImageFiles.add(image);
      }
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  void _removeNewImage(int index) {
    setState(() {
      _newImageFiles.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_selectedSubjectId == null) return;
    setState(() => _isSaving = true);

    try {
      final Map<String, String> prompts = {};
      final Map<String, String> answers = {};

      _promptControllers.forEach((lang, ctrl) {
        if (ctrl.text.isNotEmpty) prompts[lang.toLowerCase()] = ctrl.text;
      });
      _answerControllers.forEach((lang, ctrl) {
        if (ctrl.text.isNotEmpty) answers[lang.toLowerCase()] = ctrl.text;
      });

      if (answers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('provide_at_least_one_answer'))),
        );
        setState(() => _isSaving = false);
        return;
      }

      final cardId = widget.existingCard?.id ?? _cardService.generateId();
      final List<String> finalImageUrls = List<String>.from(_existingImageUrls);

      // Upload new images
      for (var file in _newImageFiles) {
        if (file == null) continue;
        final url = await _cardService.uploadCardImageXFile(cardId, file);
        if (url != null) finalImageUrls.add(url);
      }

      final now = DateTime.now();
      final card = CardModel(
        id: cardId,
        subjectId: _selectedSubjectId!,
        level: int.tryParse(_levelController.text) ?? 1,
        prompts: prompts,
        answers: answers,
        videoUrl:
            _videoUrlController.text.isEmpty ? null : _videoUrlController.text,
        imageUrl: finalImageUrls.isNotEmpty ? finalImageUrls.first : null,
        imageUrls: finalImageUrls,
        ownerId: _authService.currentUser!.serverId!,
        isPublic: false,
        createdAt: widget.existingCard?.createdAt ?? now,
        updatedAt: now,
      );

      await _cardService.addCard(card);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      AppLogger.log('Error saving card: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving card: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    const appBarColor = Colors.white;
    final pillar = pillars.firstWhere(
      (p) => p.id == _selectedPillar,
      orElse: () => pillars.first,
    );
    final currentSessionColor = pillar.getColor();
    final subject = _mySubjects.firstWhere(
      (s) => s.id == _selectedSubjectId,
      orElse:
          () =>
              _mySubjects.isNotEmpty
                  ? _mySubjects.first
                  : SubjectModel(
                    id: '',
                    name: '...',
                    pillarId: 1,
                    ownerId: '',
                    isPublic: false,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  ),
    );

    return ResizeWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AlioloAppBar(
          title: Text(
            "${subject.name}: ${widget.isReadOnly ? context.t('card_details') : (widget.existingCard == null ? context.t('add_card') : context.t('edit_card'))}",
            style: const TextStyle(color: appBarColor),
          ),
          backgroundColor: currentSessionColor,
          foregroundColor: appBarColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: appBarColor),
              onPressed: () => Navigator.pop(context),
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
        ),
        body: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const SizedBox(height: 100),
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                                        message: TranslationService()
                                            .getLanguageName(lang),
                                        child: SizedBox(
                                          width: 40,
                                          child: Text(
                                            lang.toUpperCase(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _promptControllers[lang],
                                          decoration: InputDecoration(
                                            labelText: context.t(
                                              'prompt_label',
                                            ),
                                          ),
                                          enabled: !widget.isReadOnly,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _answerControllers[lang],
                                          decoration: InputDecoration(
                                            labelText: context.t('answer'),
                                          ),
                                          enabled: !widget.isReadOnly,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          TextButton(
                            onPressed:
                                () => setState(
                                  () => _showAllLangs = !_showAllLangs,
                                ),
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
                                      ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                      : Text(
                                        context.t('save_card'),
                                        style: const TextStyle(fontSize: 18),
                                      ),
                            ),
                          const SizedBox(height: 48),
                        ],
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
              child: Text(
                'No images added',
                style: TextStyle(color: Colors.grey),
              ),
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
                        () => _pickImage(
                          replaceIndex: entry.key,
                          isExisting: true,
                        ),
                  ),
                ),
                ..._newImageFiles.asMap().entries.map(
                  (entry) => _buildImageThumbnail(
                    file: entry.value,
                    onRemove: () => _removeNewImage(entry.key),
                    onReplace:
                        () => _pickImage(
                          replaceIndex: entry.key,
                          isExisting: false,
                        ),
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
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onReplace,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 16,
                      ),
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
