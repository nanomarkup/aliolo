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

class DraftLocalizedSubjectData {
  String name = '';
  String description = '';

  DraftLocalizedSubjectData();

  factory DraftLocalizedSubjectData.fromModel(LocalizedSubjectData data) {
    final d = DraftLocalizedSubjectData();
    d.name = data.name ?? '';
    d.description = data.description ?? '';
    return d;
  }
}

class _SubjectEditPageState extends State<SubjectEditPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _formKey = GlobalKey<FormState>();

  late int _selectedPillar;
  late bool _isPublic;
  late String _selectedAgeGroup;
  String _selectedLang = 'global';
  bool _isSaving = false;

  final Map<String, DraftLocalizedSubjectData> _drafts = {
    'global': DraftLocalizedSubjectData(),
  };

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPillar = widget.existingSubject?.pillarId ?? widget.pillarId ?? 1;
    _isPublic = widget.existingSubject?.isPublic ?? false;
    _selectedAgeGroup = widget.existingSubject?.ageGroup ?? 'all';

    _initDrafts();
    _updateControllers();
  }

  void _initDrafts() {
    final availableLangs = TranslationService().availableUILanguages;
    for (var lang in availableLangs) {
      _drafts[lang.toLowerCase()] = DraftLocalizedSubjectData();
    }

    if (widget.existingSubject != null) {
      widget.existingSubject!.localizedData.forEach((lang, data) {
        _drafts[lang] = DraftLocalizedSubjectData.fromModel(data);
      });
    }
  }

  void _ensureDraftExists(String lang) {
    if (!_drafts.containsKey(lang)) {
      _drafts[lang] = DraftLocalizedSubjectData();
    }
  }

  void _updateControllers() {
    _ensureDraftExists(_selectedLang);
    final draft = _drafts[_selectedLang]!;
    _nameController.text = draft.name;
    _descriptionController.text = draft.description;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _showJsonDialog() {
    final Map<String, dynamic> data = {
      'pillarId': _selectedPillar,
      'isPublic': _isPublic,
      'ageGroup': _selectedAgeGroup,
      'localizedData': _drafts.map(
        (key, value) => MapEntry(key, {
          if (value.name.isNotEmpty) 'name': value.name,
          if (value.description.isNotEmpty) 'description': value.description,
        }),
      ),
    };

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
                              if (parsed['pillarId'] is int) {
                                _selectedPillar = parsed['pillarId'];
                              }
                              if (parsed['isPublic'] is bool) {
                                _isPublic = parsed['isPublic'];
                              }
                              if (parsed['ageGroup'] is String) {
                                _selectedAgeGroup = parsed['ageGroup'];
                              }
                              if (parsed['localizedData'] is Map) {
                                final locData = parsed['localizedData'] as Map;
                                locData.forEach((lang, val) {
                                  final l = lang.toString().toLowerCase();
                                  _ensureDraftExists(l);
                                  final d = val as Map<String, dynamic>;
                                  _drafts[l]!.name = d['name'] ?? '';
                                  _drafts[l]!.description =
                                      d['description'] ?? '';
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
                    title: const Text('JSON Data'),
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
                  const Text('JSON Data'),
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
    if (!_formKey.currentState!.validate()) return;

    final Map<String, LocalizedSubjectData> finalData = {};

    for (var entry in _drafts.entries) {
      final lang = entry.key;
      final draft = entry.value;

      if (lang != 'global' && draft.name.isEmpty && draft.description.isEmpty) {
        continue;
      }

      finalData[lang] = LocalizedSubjectData(
        name: draft.name.isEmpty ? null : draft.name,
        description: draft.description.isEmpty ? null : draft.description,
      );
    }

    if (finalData.isEmpty ||
        (finalData.length == 1 &&
            finalData.containsKey('global') &&
            finalData['global']!.name == null)) {
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
        localizedData: finalData,
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
        (draft.name.isNotEmpty || draft.description.isNotEmpty);

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

  Widget _buildEditor() {
    _ensureDraftExists(_selectedLang);
    final draft = _drafts[_selectedLang]!;
    final isGlobal = _selectedLang == 'global';
    final isOwner =
        widget.existingSubject == null ||
        widget.existingSubject!.ownerId == _authService.currentUser?.serverId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isGlobal) ...[
          _buildSectionCaption(context.t('common_settings')),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selectedPillar,
                  decoration: InputDecoration(
                    labelText: context.t('pillar'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items:
                      pillars
                          .map(
                            (p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                p.getTranslatedName(
                                  TranslationService()
                                      .currentLocale
                                      .languageCode,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      isOwner
                          ? (val) {
                            if (val != null) {
                              setState(() => _selectedPillar = val);
                            }
                          }
                          : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedAgeGroup,
                  decoration: InputDecoration(
                    labelText: context.t('age_group'),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'all',
                      child: Text(context.t('age_all')),
                    ),
                    DropdownMenuItem(
                      value: '0_6',
                      child: Text(context.t('age_0_6')),
                    ),
                    DropdownMenuItem(
                      value: '7_14',
                      child: Text(context.t('age_7_14')),
                    ),
                    DropdownMenuItem(
                      value: '15_plus',
                      child: Text(context.t('age_15_plus')),
                    ),
                  ],
                  onChanged:
                      isOwner
                          ? (val) {
                            if (val != null) {
                              setState(() => _selectedAgeGroup = val);
                            }
                          }
                          : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('public_subject')),
            subtitle: Text(context.t('public_subject_desc')),
            value: _isPublic,
            onChanged:
                isOwner ? (val) => setState(() => _isPublic = val) : null,
          ),
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
          controller: _nameController,
          onChanged: (v) => draft.name = v,
          decoration: InputDecoration(
            labelText: context.t('name'),
            border: const OutlineInputBorder(),
          ),
          enabled: isOwner,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          onChanged: (v) => draft.description = v,
          decoration: InputDecoration(
            labelText: context.t('description'),
            border: const OutlineInputBorder(),
          ),
          maxLines: 2,
          enabled: isOwner,
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  bool _hasUnsavedChanges() {
    for (var draft in _drafts.values) {
      if (draft.name.isNotEmpty || draft.description.isNotEmpty) {
        if (widget.existingSubject == null) return true;
        // For existing subjects, compare with original data
        // (Simplification: if it's not empty and we're editing, assume change for now)
        // A more robust check would compare with widget.existingSubject.localizedData
        return true; 
      }
    }
    return false;
  }

  Future<bool> _onWillPop() async {
    if (_isSaving || !_hasUnsavedChanges()) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('discard_changes')),
        content: Text(context.t('unsaved_changes_msg')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(context.t('discard')),
          ),
        ],
      ),
    );
    return result ?? false;
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: AlioloScrollablePage(
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
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
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
              icon: const Icon(Icons.data_object, color: appBarColor),
              onPressed: _showJsonDialog,
            ),
          if (isOwner && widget.existingSubject != null)
            IconButton(
              icon: const Icon(Icons.delete, color: appBarColor),
              onPressed: () async {
                final cardCount = widget.existingSubject!.cardCount;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: Text(context.t('delete_subject')),
                        content: Text(
                          cardCount > 0
                              ? 'This subject contains $cardCount ${context.plural('card', cardCount)}. Deleting it will permanently remove all of them.'
                              : 'Delete this subject?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(context.t('cancel')),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: Text(context.t('delete')),
                          ),
                        ],
                      ),
                );
                if (confirmed == true && mounted) {
                  await _cardService.deleteSubjectById(
                    widget.existingSubject!.id,
                  );
                  if (mounted) {
                    Navigator.pop(context); // Close edit page
                    Navigator.pop(context, true); // Signal parent to refresh
                  }
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
        body: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildEditor(),
          ),
        ),
      ),
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
}
