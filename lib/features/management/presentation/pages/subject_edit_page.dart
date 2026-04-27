import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/features/management/presentation/utils/localized_data_json.dart';
import 'package:aliolo/features/feedback/presentation/pages/feedback_page.dart';
import 'package:aliolo/features/settings/presentation/pages/premium_upgrade_page.dart';

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
  Map<String, dynamic> rawData = {};

  DraftLocalizedSubjectData();
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
  bool _showSidebar = false;
  int _itemsPerRow = 8;
  List<FolderModel> _allFolders = [];

  final Map<String, DraftLocalizedSubjectData> _drafts = {
    'global': DraftLocalizedSubjectData(),
  };

  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _editorFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadSidebarState();

    // Premium Locking: Redirect if creating new and not premium
    if (widget.existingSubject == null && widget.existingFolder == null) {
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
    await _cardService.getDashboardSubjects();
  }

  Future<void> _loadFolders() async {
    final results = await _cardService.getFoldersByPillar(_selectedPillar);
    if (mounted) {
      final myId = _authService.currentUser?.serverId;
      const superUserId = 'usyeo7d2yzf2773';
      
      setState(() {
        _allFolders = results.where((f) => 
          f.ownerId == myId || f.ownerId == superUserId
        ).toList();
      });
    }
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (!_showSidebar) return;

    // Do not navigate languages if user is typing in a text field
    if (_editorFocusNode.hasFocus) return;

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
      final s = widget.existingSubject!;
      _drafts['global'] = DraftLocalizedSubjectData()
        ..name = s.name
        ..description = s.description;
      
      s.names.forEach((lang, name) {
        _ensureDraftExists(lang);
        _drafts[lang]!.name = name;
      });
      s.descriptions.forEach((lang, desc) {
        _ensureDraftExists(lang);
        _drafts[lang]!.description = desc;
      });
    } else if (widget.existingFolder != null) {
      final f = widget.existingFolder!;
      _drafts['global'] = DraftLocalizedSubjectData()
        ..name = f.name;

      f.names.forEach((lang, name) {
        _ensureDraftExists(lang);
        _drafts[lang]!.name = name;
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

  LocalizedJsonEditorMode get _jsonEditorMode {
    if (_isFolderMode) return LocalizedJsonEditorMode.folder;
    return _selectedType == 'collection'
        ? LocalizedJsonEditorMode.collection
        : LocalizedJsonEditorMode.subject;
  }

  Map<String, Map<String, String>> _buildJsonDrafts() {
    return _drafts.map((key, value) {
      final draft = <String, String>{
        'name': value.name,
      };
      if (!_isFolderMode) {
        draft['description'] = value.description;
      }
      return MapEntry(key, draft);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _keyboardFocusNode.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _showJsonDialog() {
    final data = buildLocalizedJsonTemplate(_jsonEditorMode, _buildJsonDrafts());

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
                            final parsed = parseLocalizedJsonTemplate(
                              _jsonEditorMode,
                              textController.text,
                            );
                            setState(() {
                              parsed.forEach((lang, val) {
                                _ensureDraftExists(lang);
                                final draft = _drafts[lang]!;
                                if (val.containsKey('name')) {
                                  draft.name = val['name'] ?? '';
                                }
                                if (!_isFolderMode &&
                                    val.containsKey('description')) {
                                  draft.description = val['description'] ?? '';
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

    String? globalName;
    String? globalDescription;
    final Map<String, String> finalNames = {};
    final Map<String, String> finalDescriptions = {};

    for (var entry in _drafts.entries) {
      final lang = entry.key;
      final draft = entry.value;

      if (lang == 'global') {
        globalName = draft.name.isEmpty ? null : draft.name;
        globalDescription = draft.description.isEmpty ? null : draft.description;
        continue;
      }

      if (draft.name.isNotEmpty) {
        finalNames[lang] = draft.name;
      }
      if (draft.description.isNotEmpty) {
        finalDescriptions[lang] = draft.description;
      }
    }

    // Ensure global name is never null
    if (globalName == null || globalName.trim().isEmpty) {
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
        final newName = globalName?.trim().toLowerCase() ?? 
                        finalNames.values.firstOrNull?.trim().toLowerCase();
        
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
          name: globalName ?? '',
          names: finalNames,
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
          name: globalName ?? '',
          names: finalNames,
          description: globalDescription ?? '',
          descriptions: finalDescriptions,
          subjectIds: _linkedSubjectIds,
          isPublic: _isPublic,
          folderId: _selectedFolderId,
          isOnDashboard: widget.existingSubject?.isOnDashboard ?? true,
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
          name: globalName ?? '',
          names: finalNames,
          description: globalDescription ?? '',
          descriptions: finalDescriptions,
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

    return Focus(
      focusNode: _editorFocusNode,
      child: Column(
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
            (() {
              final folderDropdown = DropdownButtonFormField<String?>(
                value: _selectedFolderId,
                decoration: InputDecoration(
                  labelText: context.t('folder'),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: (() {
                  final items = [
                    DropdownMenuItem<String?>(value: null, child: const Text('')),
                    ..._allFolders.map(
                      (f) => DropdownMenuItem(
                        value: f.id,
                        child: Text(
                          f.getName(currentLang),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ];

                  if (_selectedFolderId != null &&
                      !items.any((item) => item.value == _selectedFolderId)) {
                    items.add(
                      DropdownMenuItem(
                        value: _selectedFolderId,
                        child: const Text('Loading...'),
                      ),
                    );
                  }
                  return items;
                })(),
                onChanged:
                    isOwner
                        ? (val) => setState(() => _selectedFolderId = val)
                        : null,
              );

              final ageDropdown = DropdownButtonFormField<String>(
                value: _selectedAgeGroup,
                decoration: InputDecoration(
                  labelText: context.t('age_group'),
                  border: const OutlineInputBorder(),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
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
              );

              if (_showSidebar) {
                return Column(
                  children: [
                    folderDropdown,
                    const SizedBox(height: 20),
                    ageDropdown,
                  ],
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: folderDropdown),
                    const SizedBox(width: 16),
                    Expanded(child: ageDropdown),
                  ],
                );
              }
            })(),
          ],
          if (!_isFolderMode) ...[
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('public_subject')),
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
             labelText: '${context.t('name')} *',
             border: const OutlineInputBorder(),
           ),
           enabled: isOwner,
           validator: (v) {
             if (_selectedLang == 'global' && (v == null || v.trim().isEmpty)) {
               return context.t('provide_at_least_one_name');
             }
             return null;
           },
         ),        if (!_isFolderMode) ...[
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
        ],
        const SizedBox(height: 48),
      ],
    ),
  );
}

  bool _hasUnsavedChanges() {
    if (widget.existingSubject == null && widget.existingFolder == null) {
      for (var draft in _drafts.values) {
        if (draft.name.trim().isNotEmpty) return true;
        if (!_isFolderMode && draft.description.trim().isNotEmpty) return true;
      }
      return false;
    }

    if (_isFolderMode) {
      final original = widget.existingFolder!;
      if (_selectedPillar != original.pillarId) return true;
      
      final allLangs = {'global', ...original.names.keys, ..._drafts.keys};
      for (var lang in allLangs) {
        final draft = _drafts[lang];
        final draftName = draft?.name.trim() ?? '';

        if (lang == 'global') {
          if (draftName != original.name.trim()) return true;
        } else {
          if (draftName != (original.names[lang]?.trim() ?? '')) return true;
        }
      }
      return false;
    }

    final original = widget.existingSubject!;
    if (_selectedPillar != original.pillarId) return true;
    if (_selectedAgeGroup != original.ageGroup) return true;
    if (_isPublic != original.isPublic) return true;
    if (_selectedType != original.typeStr) return true;
    if ((_selectedFolderId ?? '') != (original.folderId ?? '')) return true;

    final allLangs = {'global', ...original.names.keys, ...original.descriptions.keys, ..._drafts.keys};
    for (var lang in allLangs) {
      final draft = _drafts[lang];
      final draftName = draft?.name.trim() ?? '';
      final draftDesc = draft?.description.trim() ?? '';

      if (lang == 'global') {
        if (draftName != original.name.trim()) return true;
        if (draftDesc != original.description.trim()) return true;
      } else {
        if (draftName != (original.names[lang]?.trim() ?? '')) return true;
        if (draftDesc != (original.descriptions[lang]?.trim() ?? '')) return true;
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;

          final backAction = IconButton(
            tooltip: context.t('back'),
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _onWillPop();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
          );

          final saveAction = isOwner
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

          final jsonAction = isOwner
              ? IconButton(
                tooltip: 'JSON',
                icon: const Icon(Icons.data_object),
                onPressed: _showJsonDialog,
              )
              : null;

          final deleteAction = (isOwner && (widget.existingSubject != null || widget.existingFolder != null))
              ? IconButton(
                tooltip: context.t('delete'),
                icon: const Icon(Icons.delete),
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
                  final cardCount = widget.existingSubject?.cardCount ?? 0;
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
              )
              : null;

          final feedbackAction = (widget.existingSubject != null || widget.existingFolder != null)
              ? IconButton(
                tooltip: context.t('feedback'),
                icon: const Icon(Icons.feedback),
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
              )
              : null;

          final currentPillarObj = pillars.firstWhere(
            (p) => p.id == _selectedPillar,
            orElse: () => pillars.first,
          );

          return AlioloScrollablePage(
            leading: Icon(
              currentPillarObj.getIconData(),
              color: appBarColor,
              size: 24,
            ),
            leadingWidth: 56,
            title: Text(
              _isFolderMode
                  ? (widget.existingFolder == null ? context.t('add_folder') : context.t('edit_folder'))
                  : _selectedType == 'collection'
                      ? (widget.existingSubject == null ? context.t('add_collection') : context.t('edit_collection'))
                      : (widget.existingSubject == null ? context.t('add_subject') : context.t('edit_subject')),
              style: const TextStyle(color: appBarColor),
            ),
            appBarColor: currentSessionColor,
            actions: isSmallScreen 
                ? [
                    backAction,
                    if (saveAction != null) saveAction,
                    IconButton(
                      tooltip: context.t('toggle_languages') ?? 'Languages',
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
                      tooltip: context.t('toggle_languages') ?? 'Languages',
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_showSidebar && isSmallScreen)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                          child: _buildLangGrid(),
                        ),
                      const SizedBox(height: 32),
                      Form(
                        key: _formKey,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _buildEditor(),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
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
