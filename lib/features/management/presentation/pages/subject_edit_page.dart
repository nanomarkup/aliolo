import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/folder_model.dart';
import 'package:aliolo/data/models/collection_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/features/feedback/presentation/pages/feedback_page.dart';

class SubjectEditPage extends StatefulWidget {
  final SubjectModel? existingSubject;
  final FolderModel? existingFolder;
  final int? pillarId;
  final String? folderId;
  final String? initialAgeGroup;
  final bool isFolderMode;
  final bool isCollectionMode;

  const SubjectEditPage({
    super.key,
    this.existingSubject,
    this.existingFolder,
    this.pillarId,
    this.folderId,
    this.initialAgeGroup,
    this.isFolderMode = false,
    this.isCollectionMode = false,
  });

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
  final _keyboardFocusNode = FocusNode();

  late int _selectedPillar;
  late bool _isPublic;
  late String _selectedAgeGroup;
  late String _selectedType;
  late bool _isFolderMode;
  String? _selectedFolderId;
  String _selectedLang = 'global';
  late List<String> _linkedSubjectIds;
  bool _isSaving = false;
  int _itemsPerRow = 8;
  List<SubjectModel> _allSubjects = [];
  List<FolderModel> _allFolders = [];

  final Map<String, DraftLocalizedSubjectData> _drafts = {
    'global': DraftLocalizedSubjectData(),
  };

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _isFolderMode = widget.isFolderMode || widget.existingFolder != null;
    _selectedPillar = widget.existingSubject?.pillarId ?? widget.existingFolder?.pillarId ?? widget.pillarId ?? 1;
    _isPublic = widget.existingSubject?.isPublic ?? false;
    _selectedAgeGroup = widget.existingSubject?.ageGroup ??
        ((widget.initialAgeGroup != null && widget.initialAgeGroup != 'all')
            ? widget.initialAgeGroup!
            : '15_plus');
    _selectedType = widget.existingSubject?.typeStr ?? 
        (widget.isCollectionMode ? 'collection' : 'standard');
    _selectedFolderId = widget.existingSubject?.folderId ?? widget.folderId;
    _linkedSubjectIds = List.from(widget.existingSubject?.linkedSubjectIds ?? []);

    if (pillars.isEmpty) {
      _cardService.getPillars().then((_) {
        if (mounted) setState(() {});
      });
    }
    
    _loadAllSubjects();
    _loadFolders();
    _initDrafts();
    _updateControllers();
  }

  Future<void> _loadAllSubjects() async {
    final results = await _cardService.getDashboardSubjects();
    if (mounted) {
      setState(() {
        _allSubjects = results;
      });
    }
  }

  Future<void> _loadFolders() async {
    final results = await _cardService.getFoldersByPillar(_selectedPillar);
    if (mounted) {
      setState(() {
        _allFolders = results;
      });
    }
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
      newIndex = (currentIndex - 1 + availableLangs.length) % availableLangs.length;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      newIndex = currentIndex + _itemsPerRow;
      if (newIndex >= availableLangs.length) {
        newIndex = currentIndex % _itemsPerRow; // Loop to top
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      newIndex = currentIndex - _itemsPerRow;
      if (newIndex < 0) {
        // Find last possible index in that column
        int lastRowStart = ((availableLangs.length - 1) ~/ _itemsPerRow) * _itemsPerRow;
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
    final availableLangs = TranslationService().availableUILanguages;
    for (var lang in availableLangs) {
      _drafts[lang.toLowerCase()] = DraftLocalizedSubjectData();
    }

    if (widget.existingSubject != null) {
      widget.existingSubject!.localizedData.forEach((lang, data) {
        _drafts[lang] = DraftLocalizedSubjectData.fromModel(data);
      });
    } else if (widget.existingFolder != null) {
      widget.existingFolder!.localizedData.forEach((lang, data) {
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
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  void _showJsonDialog() {
    final Map<String, dynamic> data = _drafts.map(
      (key, value) => MapEntry(key, {
        if (value.name.isNotEmpty) 'name': value.name,
        if (value.description.isNotEmpty) 'description': value.description,
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
                                  _drafts[l]!.name = d['name']?.toString() ?? '';
                                  _drafts[l]!.description =
                                      d['description']?.toString() ?? '';
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
      final myId = _authService.currentUser?.serverId;
      
      if (_isFolderMode) {
        // Validation: Prevent duplicate folder names for this user in this pillar
        final newName = finalData['global']?.name?.trim().toLowerCase() ?? 
                        finalData.values.firstWhere((d) => d.name != null, orElse: () => LocalizedSubjectData()).name?.trim().toLowerCase();
        
        if (newName != null) {
          final isDuplicate = _allFolders.any((f) => 
            f.ownerId == myId && 
            f.id != widget.existingFolder?.id &&
            f.getName('global').trim().toLowerCase() == newName
          );

          if (isDuplicate) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.t('folder_already_exists') ?? 'A folder with this name already exists in this pillar')),
              );
              setState(() => _isSaving = false);
            }
            return;
          }
        }

        final folderId = widget.existingFolder?.id ?? _cardService.generateId();
        final folder = FolderModel(
          id: folderId,
          pillarId: _selectedPillar,
          ownerId: widget.existingFolder?.ownerId ?? _authService.currentUser!.serverId!,
          createdAt: widget.existingFolder?.createdAt ?? now,
          updatedAt: now,
          localizedData: finalData,
        );
        await _cardService.addFolder(folder);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('save_success') ?? 'Saved successfully')),
          );
          Navigator.pop(context, true);
        }
      } else if (_selectedType == 'collection') {
        final collectionId = widget.existingSubject?.id ?? _cardService.generateId();
        final collection = CollectionModel(
          id: collectionId,
          pillarId: _selectedPillar,
          ageGroup: _selectedAgeGroup,
          ownerId: widget.existingSubject?.ownerId ?? _authService.currentUser!.serverId!,
          createdAt: widget.existingSubject?.createdAt ?? now,
          updatedAt: now,
          localizedData: finalData,
          subjectIds: _linkedSubjectIds,
          isPublic: _isPublic,
          folderId: _selectedFolderId,
          isOnDashboard: widget.existingSubject?.isOnDashboard ?? false,
        );
        await _cardService.addCollection(collection, _linkedSubjectIds);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('save_success') ?? 'Saved successfully')),
          );
          // If it's a new collection, return the object so we can navigate to it
          if (widget.existingSubject == null) {
            Navigator.pop(context, collection);
          } else {
            Navigator.pop(context, true);
          }
        }
      } else {
        final subjectId = widget.existingSubject?.id ?? _cardService.generateId();
        final subject = SubjectModel(
          id: subjectId,
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
          typeStr: 'standard',
          folderId: _selectedFolderId,
          linkedSubjectIds: [],
        );
        await _cardService.addSubject(subject);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.t('save_success') ?? 'Saved successfully')),
          );
          // If it's a new subject, return the object so we can navigate to it
          if (widget.existingSubject == null) {
            Navigator.pop(context, subject);
          } else {
            Navigator.pop(context, true);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
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
        (widget.existingSubject == null && widget.existingFolder == null) ||
        widget.existingSubject?.ownerId == _authService.currentUser?.serverId ||
        widget.existingFolder?.ownerId == _authService.currentUser?.serverId;

    final currentLang = TranslationService().currentLocale.languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isGlobal) ...[
          _buildSectionCaption(context.t('common_settings')),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedPillar,
            decoration: InputDecoration(
              labelText: context.t('pillar'),
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            items: pillars.map((p) => DropdownMenuItem(
              value: p.id,
              child: Text(p.getTranslatedName(currentLang)),
            )).toList(),
            onChanged: isOwner ? (val) {
              if (val != null) {
                setState(() {
                  _selectedPillar = val;
                  _selectedFolderId = null;
                  _loadFolders();
                });
              }
            } : null,
          ),
          if (!_isFolderMode) ...[
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _selectedFolderId,
                    decoration: InputDecoration(
                      labelText: context.t('folder'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: (() {
                      final items = [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(context.t('no_folder')),
                        ),
                        ..._allFolders.map((f) => DropdownMenuItem(
                          value: f.id,
                          child: Text(f.getName(currentLang), overflow: TextOverflow.ellipsis),
                        )),
                      ];

                      // Safety: Ensure current selected ID is in the list to avoid assertion during initial load
                      if (_selectedFolderId != null && !items.any((item) => item.value == _selectedFolderId)) {
                        items.add(
                          DropdownMenuItem(
                            value: _selectedFolderId,
                            child: const Text('Loading...'),
                          ),
                        );
                      }
                      return items;
                    })(),
                    onChanged: isOwner ? (val) => setState(() => _selectedFolderId = val) : null,
                  ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedAgeGroup,
                    decoration: InputDecoration(
                      labelText: context.t('age_group'),
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: [
                      DropdownMenuItem(value: '0_6', child: Text(context.t('age_0_6'))),
                      DropdownMenuItem(value: '7_14', child: Text(context.t('age_7_14'))),
                      DropdownMenuItem(value: '15_plus', child: Text(context.t('age_15_plus'))),
                    ],
                    onChanged: isOwner ? (val) {
                      if (val != null) setState(() => _selectedAgeGroup = val);
                    } : null,
                  ),
                  ),
                  ],
                  ),
                  ],
          if (!_isFolderMode) ...[
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('public_subject')),
              subtitle: Text(context.t('public_subject_desc')),
              value: _isPublic,
              onChanged: isOwner ? (val) => setState(() => _isPublic = val) : null,
            ),
          ],
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
    if (widget.existingSubject == null && widget.existingFolder == null) {
      for (var draft in _drafts.values) {
        if (draft.name.isNotEmpty || draft.description.isNotEmpty) return true;
      }
      return false;
    }

    if (_isFolderMode) {
      final original = widget.existingFolder!;
      if (_selectedPillar != original.pillarId) return true;
      final allLangs = {...original.localizedData.keys, ..._drafts.keys};
      for (var lang in allLangs) {
        if ((_drafts[lang]?.name ?? '') != (original.localizedData[lang]?.name ?? '') || 
            (_drafts[lang]?.description ?? '') != (original.localizedData[lang]?.description ?? '')) return true;
      }
      return false;
    }

    final original = widget.existingSubject!;
    if (_selectedPillar != original.pillarId) return true;
    if (_selectedAgeGroup != original.ageGroup) return true;
    if (_isPublic != original.isPublic) return true;
    if (_selectedType != original.typeStr) return true;
    if (_selectedFolderId != original.folderId) return true;

    final allLangs = {...original.localizedData.keys, ..._drafts.keys};
    for (var lang in allLangs) {
      final draft = _drafts[lang];
      final orig = original.localizedData[lang];
      if ((draft?.name ?? '') != (orig?.name ?? '') || (draft?.description ?? '') != (orig?.description ?? '')) return true;
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
    final isDarkMode = getIt<ThemeService>().isDarkMode;
    final currentSessionColor = pillar.getColor(isDarkMode);
    final isOwner =
        (widget.existingSubject == null && widget.existingFolder == null) ||
        widget.existingSubject?.ownerId == _authService.currentUser?.serverId ||
        widget.existingFolder?.ownerId == _authService.currentUser?.serverId;
    
    final currentLang = TranslationService().currentLocale.languageCode;

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
          _isFolderMode
              ? (widget.existingFolder == null ? context.t('add_folder') : context.t('edit_folder'))
              : _selectedType == 'collection'
                  ? (widget.existingSubject == null ? context.t('add_collection') : context.t('edit_collection'))
                  : (widget.existingSubject == null ? context.t('add_subject') : context.t('edit_subject')),
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
          if (isOwner && (widget.existingSubject != null || widget.existingFolder != null))
            IconButton(
              icon: const Icon(Icons.delete, color: appBarColor),
              onPressed: () async {
                if (_isFolderMode) {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          title: Text(context.t('delete_folder')),
                          content: const Text('Are you sure you want to delete this folder?'),
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
                    try {
                      await _cardService.deleteFolder(widget.existingFolder!.id);
                      if (mounted) Navigator.pop(context, true);
                    } catch (e) {
                      if (e.toString().contains('folder_not_empty') && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('folder_not_empty_msg') ?? 'Cannot delete folder: it is not empty')));
                      }
                    }
                  }
                  return;
                }

                final isCollection = _selectedType == 'collection';
                final cardCount = widget.existingSubject!.cardCount;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: Text(isCollection ? context.t('delete_collection') : context.t('delete_subject')),
                        content: Text(
                          isCollection
                              ? context.t('delete_collection_confirm')
                              : (cardCount > 0
                                  ? 'This subject contains $cardCount ${context.plural('card', cardCount)}. Deleting it will permanently remove all of them.'
                                  : 'Delete this subject?'),
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
                  if (isCollection) {
                    await _cardService.deleteCollection(widget.existingSubject!.id);
                  } else {
                    await _cardService.deleteSubjectById(widget.existingSubject!.id);
                  }
                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.pop(context, true);
                  }
                }
              },
            ),
          if (widget.existingSubject != null || widget.existingFolder != null)
            IconButton(
              icon: const Icon(Icons.feedback, color: appBarColor),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => FeedbackPage(
                          subjectId: widget.existingSubject?.id,
                          folderId: widget.existingFolder?.id,
                          contextTitle:
                              _isFolderMode 
                                ? widget.existingFolder!.getName(currentLang)
                                : widget.existingSubject!.getName(currentLang),
                          appBarColor: currentSessionColor,
                        ),
                  ),
                );
              },
            ),
        ],
        fixedBody: KeyboardListener(
          focusNode: _keyboardFocusNode,
          autofocus: true,
          onKeyEvent: _onKeyEvent,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth - 32;
              final items = (availableWidth + 8) ~/ 62;
              _itemsPerRow = items > 0 ? items : 1;

              return Padding(
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
                        })(),                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
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
