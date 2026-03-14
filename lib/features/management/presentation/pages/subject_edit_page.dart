import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';

class SubjectEditPage extends StatefulWidget {
  final SubjectModel? existingSubject;
  final int? pillarId;

  const SubjectEditPage({super.key, this.existingSubject, this.pillarId});

  @override
  State<SubjectEditPage> createState() => _SubjectEditPageState();
}

class _SubjectEditPageState extends State<SubjectEditPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _formKey = GlobalKey<FormState>();

  late int _selectedPillar;
  late bool _isPublic;
  late String _selectedAgeGroup;
  bool _showAllLangs = false;
  bool _isSaving = false;

  final Map<String, TextEditingController> _nameControllers = {};
  final Map<String, TextEditingController> _descriptionControllers = {};

  @override
  void initState() {
    super.initState();
    _selectedPillar = widget.existingSubject?.pillarId ?? widget.pillarId ?? 1;
    _isPublic = widget.existingSubject?.isPublic ?? false;
    _selectedAgeGroup = widget.existingSubject?.ageGroup ?? 'advanced';

    _initLanguageControllers();
  }

  void _initLanguageControllers() {
    final allLangs = TranslationService().availableUILanguages;
    final subject = widget.existingSubject;

    for (var lang in allLangs) {
      final code = lang.toLowerCase();
      _nameControllers[lang] = TextEditingController(
        text: subject?.names[code] ?? '',
      );
      _descriptionControllers[lang] = TextEditingController(
        text: subject?.descriptions[code] ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (var c in _nameControllers.values) {
      c.dispose();
    }
    for (var c in _descriptionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _showJsonDialog() {
    final allLangs = TranslationService().availableUILanguages;
    final Map<String, String> schemaNames = {};
    final Map<String, String> schemaDescriptions = {};

    for (var lang in allLangs) {
      final code = lang.toLowerCase();
      schemaNames[code] = _nameControllers[lang]?.text ?? '';
      schemaDescriptions[code] = _descriptionControllers[lang]?.text ?? '';
    }

    final Map<String, dynamic> data = {
      'pillarId': _selectedPillar,
      'isPublic': _isPublic,
      'ageGroup': _selectedAgeGroup,
      'names': schemaNames,
      'descriptions': schemaDescriptions,
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
                          if (parsed['pillarId'] is int) {
                            _selectedPillar = parsed['pillarId'];
                          }
                          if (parsed['isPublic'] is bool) {
                            _isPublic = parsed['isPublic'];
                          }
                          if (parsed['ageGroup'] is String) {
                            _selectedAgeGroup = parsed['ageGroup'];
                          }
                          if (parsed['names'] is Map) {
                            final names = parsed['names'] as Map;
                            names.forEach((lang, val) {
                              final l = lang.toString();
                              if (_nameControllers.containsKey(l)) {
                                _nameControllers[l]!.text = val.toString();
                              }
                            });
                          }
                          if (parsed['descriptions'] is Map) {
                            final descs = parsed['descriptions'] as Map;
                            descs.forEach((lang, val) {
                              final l = lang.toString();
                              if (_descriptionControllers.containsKey(l)) {
                                _descriptionControllers[l]!.text =
                                    val.toString();
                              }
                            });
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
    if (!_formKey.currentState!.validate()) return;

    final Map<String, String> names = {};
    final Map<String, String> descriptions = {};

    for (var entry in _nameControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        names[entry.key.toLowerCase()] = entry.value.text;
      }
    }
    for (var entry in _descriptionControllers.entries) {
      if (entry.value.text.isNotEmpty) {
        descriptions[entry.key.toLowerCase()] = entry.value.text;
      }
    }

    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('provide_at_least_one_name'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final subject = SubjectModel(
        id: widget.existingSubject?.id ?? '',
        names: names,
        descriptions: descriptions,
        pillarId: _selectedPillar,
        ageGroup: _selectedAgeGroup,
        ownerId:
            widget.existingSubject?.ownerId ??
            _authService.currentUser!.serverId!,
        ownerName:
            widget.existingSubject?.ownerName ??
            _authService.currentUser!.username,
        isPublic: _isPublic,
        isOnDashboard: widget.existingSubject?.isOnDashboard ?? true,
        cardCount: widget.existingSubject?.cardCount ?? 0,
        createdAt: widget.existingSubject?.createdAt ?? now,
        updatedAt: now,
      );

      await _cardService.saveSubject(subject);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving subject: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    final pillar = pillars.firstWhere(
      (p) => p.id == _selectedPillar,
      orElse: () => pillars.first,
    );
    final currentSessionColor = pillar.getColor();
    final isOwner =
        widget.existingSubject == null ||
        widget.existingSubject!.ownerId == _authService.currentUser?.serverId;

    return AlioloScrollablePage(
      title: Text(
        widget.existingSubject == null
            ? context.t('add_subject')
            : context.t('edit_subject'),
        style: const TextStyle(color: appBarColor),
      ),
      appBarColor: currentSessionColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
        if (isOwner)
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
        if (isOwner)
          IconButton(
            icon: const Icon(Icons.code, color: appBarColor),
            onPressed: _showJsonDialog,
          ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            if (widget.pillarId == null && widget.existingSubject == null) ...[
              _buildSectionCaption(context.t('pillar')),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                value: _selectedPillar,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items:
                    pillars
                        .map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.getTranslatedName(
                                TranslationService().currentLocale.languageCode,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedPillar = val);
                },
              ),
              const SizedBox(height: 24),
            ],

            _buildSectionCaption(context.t('visibility')),
            SwitchListTile(
              title: Text(context.t('public_subject')),
              subtitle: Text(context.t('public_subject_desc')),
              value: _isPublic,
              onChanged:
                  isOwner ? (val) => setState(() => _isPublic = val) : null,
            ),
            const SizedBox(height: 24),
            _buildSectionCaption(context.t('age_group')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedAgeGroup,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: [
                DropdownMenuItem(
                  value: 'early',
                  child: Text(context.t('age_early')),
                ),
                DropdownMenuItem(
                  value: 'primary',
                  child: Text(context.t('age_primary')),
                ),
                DropdownMenuItem(
                  value: 'intermediate',
                  child: Text(context.t('age_intermediate')),
                ),
                DropdownMenuItem(
                  value: 'advanced',
                  child: Text(context.t('age_advanced')),
                ),
              ],
              onChanged:
                  isOwner
                      ? (val) {
                        if (val != null)
                          setState(() => _selectedAgeGroup = val);
                      }
                      : null,
            ),
            const SizedBox(height: 24),
            _buildSectionCaption(context.t('names_descriptions')),
            const SizedBox(height: 12),
            ..._nameControllers.keys
                .where(
                  (lang) =>
                      _showAllLangs ||
                      lang == 'en' ||
                      _nameControllers[lang]!.text.isNotEmpty ||
                      _descriptionControllers[lang]!.text.isNotEmpty,
                )
                .map(
                  (lang) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                lang.toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Text(
                              TranslationService().getLanguageName(lang),
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameControllers[lang],
                          decoration: InputDecoration(
                            labelText: context.t('name'),
                            border: const OutlineInputBorder(),
                          ),
                          enabled: isOwner,
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _descriptionControllers[lang],
                          decoration: InputDecoration(
                            labelText: context.t('description'),
                            border: const OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          enabled: isOwner,
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
}
