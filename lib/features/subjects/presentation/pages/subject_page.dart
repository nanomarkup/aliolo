import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/folder_model.dart';
import 'package:aliolo/data/models/collection_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_landing_page.dart';
import 'package:aliolo/features/management/presentation/pages/subject_edit_page.dart';
import 'package:aliolo/data/services/feedback_service.dart';

import 'package:aliolo/features/feedback/presentation/pages/feedback_page.dart';

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final _cardService = getIt<CardService>();
  final _searchController = TextEditingController();
  final _authService = getIt<AuthService>();

  String _currentTestingLang = 'en';
  bool _isLangInitialized = false;

  List<SubjectModel> _allDashboardSubjects = [];
  List<FolderModel> _allDashboardFolders = [];
  List<CollectionModel> _allDashboardCollections = [];
  List<SubjectModel> _allMatchingSubjects = [];
  List<CollectionModel> _allMatchingCollections = [];
  List<SubjectModel> _filteredSubjects = [];
  List<CollectionModel> _filteredCollections = [];
  List<FolderModel> _filteredFolders = [];
  bool _isLoading = true;
  String _selectedAgeFilter = 'all';
  String _collectionFilter = 'favorites';

  @override
  void initState() {
    super.initState();
    ThemeService().setSessionColor(ThemeService().primaryColor);
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    _initLanguage();
    _loadDashboard();
    _cardService.addListener(_loadDashboard);
  }

  @override
  void dispose() {
    getIt<AuthService>().removeListener(_onAuthChanged);
    _cardService.removeListener(_loadDashboard);
    _searchController.dispose();
    super.dispose();
  }

  void _initLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('last_testing_lang');
    final savedAgeFilter = prefs.getString('last_age_filter');
    final savedCollectionFilter = prefs.getString('last_collection_filter');

    if (mounted) {
      setState(() {
        if (savedLang != null) {
          _currentTestingLang = savedLang;
          _isLangInitialized = true;
        } else {
          final user = getIt<AuthService>().currentUser;
          if (user != null) {
            _currentTestingLang = user.defaultLanguage.toLowerCase();
            _isLangInitialized = true;
          }
        }
        if (savedAgeFilter != null) {
          _selectedAgeFilter = savedAgeFilter;
        }
        if (savedCollectionFilter != null) {
          _collectionFilter = savedCollectionFilter;
        }
      });
    }
    getIt<AuthService>().addListener(_onAuthChanged);
  }

  void _onAuthChanged() async {
    if (mounted && !_isLangInitialized) {
      final prefs = await SharedPreferences.getInstance();
      final savedLang = prefs.getString('last_testing_lang');
      if (savedLang != null) {
        setState(() {
          _currentTestingLang = savedLang;
          _isLangInitialized = true;
        });
        return;
      }

      final user = getIt<AuthService>().currentUser;
      if (user != null) {
        setState(() {
          _currentTestingLang = user.defaultLanguage.toLowerCase();
          _isLangInitialized = true;
        });
      }
    }
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    await _cardService.getPillars();
    final subjects = await _cardService.getDashboardSubjects();
    final collections = await _cardService.getAllCollections(rootOnly: false);
    
    final myFolders = await _cardService.getAllFolders();
    final foreignFolderIds = {
      ...subjects.where((s) => s.folderId != null).map((s) => s.folderId!),
      ...collections.where((c) => c.folderId != null).map((c) => c.folderId!),
    }.where((fid) => !myFolders.any((f) => f.id == fid)).toList();
    
    final List<FolderModel> allFolders = [...myFolders];
    if (foreignFolderIds.isNotEmpty) {
      final foreignFolders = await _cardService.getFoldersByIds(foreignFolderIds);
      allFolders.addAll(foreignFolders);
    }

    if (mounted) {
      final Set<String> detectedLangs = {};
      for (var s in subjects) {
        detectedLangs.addAll(s.localizedData.keys.map((k) => k.toLowerCase()));
        if (s.rawCards != null) {
          for (var c in s.rawCards!) {
            final locData = c['localized_data'] as Map?;
            if (locData != null) {
              detectedLangs.addAll(locData.keys.map((k) => k.toString().toLowerCase()));
            }
          }
        }
      }
      detectedLangs.remove('global');
      detectedLangs.remove('default');
      if (detectedLangs.isNotEmpty) {
        getIt<TestingLanguageService>().addActiveLanguages(detectedLangs.toList());
      }

      final prefs = await SharedPreferences.getInstance();
      final hasSavedCollection = prefs.containsKey('last_collection_filter');

      setState(() {
        _allDashboardSubjects = subjects;
        _allDashboardFolders = allFolders;
        _allDashboardCollections = collections;
        if (!hasSavedCollection && _allDashboardSubjects.where((s) => s.isOnDashboard).isEmpty) {
          _collectionFilter = 'public';
        }
        _applySearch();
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    final query = _searchController.text.toLowerCase();
    final myId = getIt<AuthService>().currentUser?.serverId;

    setState(() {
      final availableFolderIds = _allDashboardFolders.map((f) => f.id).toSet();

      _allMatchingSubjects = _allDashboardSubjects.where((s) {
        final matchesName = s.getName(_currentTestingLang).toLowerCase().contains(query);
        final matchesAge = _selectedAgeFilter == 'all' || s.ageGroup == _selectedAgeFilter;
        bool matchesCollection = true;
        if (_collectionFilter == 'mine') {
          matchesCollection = s.ownerId == myId;
        } else if (_collectionFilter == 'public') {
          matchesCollection = s.isPublic;
        } else {
          // 'favorites' (Dashboard)
          matchesCollection = s.isOnDashboard;
        }
        return matchesName && matchesAge && matchesCollection;
      }).toList();

      _allMatchingCollections = _allDashboardCollections.where((c) {
        final matchesName = c.getName(_currentTestingLang).toLowerCase().contains(query);
        bool matchesCollection = true;
        if (_collectionFilter == 'mine') {
          matchesCollection = c.ownerId == myId;
        } else if (_collectionFilter == 'public') {
          matchesCollection = c.isPublic;
        } else {
          // 'favorites' (Dashboard)
          matchesCollection = true; // For now all public collections are on dashboard? Or implement bridge table too?
        }
        return matchesName && matchesCollection;
      }).toList();

      _filteredSubjects = _allMatchingSubjects.where((s) {
        return query.isNotEmpty || s.folderId == null || !availableFolderIds.contains(s.folderId);
      }).toList();

      _filteredCollections = _allMatchingCollections.where((c) {
        return query.isNotEmpty || c.folderId == null || !availableFolderIds.contains(c.folderId);
      }).toList();

      _filteredFolders = _allDashboardFolders.where((f) {
        final matchesQuery = f.getName(_currentTestingLang).toLowerCase().contains(query);
        final hasMatchingContent = _allMatchingSubjects.any((s) => s.folderId == f.id) || 
                                 _allMatchingCollections.any((c) => c.folderId == f.id);
        
        if (hasMatchingContent) return true;
        if (_collectionFilter == 'mine' || _collectionFilter == 'all') {
          return f.ownerId == myId && matchesQuery;
        }
        return false;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    return ListenableBuilder(
      listenable: Listenable.merge([
        _cardService,
        TranslationService(),
        ThemeService(),
        getIt<TestingLanguageService>(),
      ]),
      builder: (context, _) {
        final isSearching = _searchController.text.isNotEmpty;
        final currentSessionColor = ThemeService().primaryColor;
        final activePillars = pillars.where((p) => 
          _allMatchingSubjects.any((s) => s.pillarId == p.id) || 
          _filteredFolders.any((f) => f.pillarId == p.id) ||
          _allMatchingCollections.any((c) => c.pillarId == p.id)
        ).toList();

        final activeCodes = getIt<TestingLanguageService>().activeLanguageCodes.map((l) => l.toLowerCase()).toSet();
        if (!activeCodes.contains(_currentTestingLang)) {
          activeCodes.add(_currentTestingLang);
        }

        return AlioloScrollablePage(
          title: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _currentTestingLang,
              dropdownColor: currentSessionColor,
              icon: const Icon(Icons.language, color: appBarColor, size: 20),
              style: const TextStyle(color: appBarColor, fontSize: 18, fontWeight: FontWeight.bold),
              items: activeCodes.map((l) {
                return DropdownMenuItem(
                  value: l,
                  child: Text(getIt<TestingLanguageService>().getLanguageName(l), style: const TextStyle(color: Colors.white)),
                );
              }).toList(),
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _currentTestingLang = val);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('last_testing_lang', val);
                  _applySearch();
                }
              },
            ),
          ),
          appBarColor: currentSessionColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.school, color: appBarColor),
              onPressed: () {
                if (isSearching) {
                  _searchController.clear();
                  _applySearch();
                } else {
                  _loadDashboard();
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())),
            ),
            IconButton(
              icon: ValueListenableBuilder<bool>(
                valueListenable: getIt<FeedbackService>().pendingNotifications,
                builder: (context, hasNotif, _) {
                  return Badge(isLabelVisible: hasNotif, backgroundColor: Colors.amber, child: const Icon(Icons.person, color: appBarColor));
                },
              ),
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
                _loadDashboard();
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
            ),
          ],
          fixedBody: LayoutBuilder(
            builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              final filterRow = Row(
                children: [
                  Expanded(
                    child: _buildCompactDropdown(
                      value: _collectionFilter,
                      items: {
                        'favorites': context.t('filter_dashboard'),
                        'mine': context.t('filter_my_subjects'),
                        'public': context.t('filter_public'),
                      },
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() { _collectionFilter = val; _applySearch(); });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('last_collection_filter', val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCompactDropdown(
                      value: _selectedAgeFilter,
                      items: {
                        'all': context.t('age_all'),
                        '0_6': context.t('age_0_6'),
                        '7_14': context.t('age_7_14'),
                        '15_plus': context.t('age_15_plus'),
                      },
                      onChanged: (val) async {
                        if (val != null) {
                          setState(() { _selectedAgeFilter = val; _applySearch(); });
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('last_age_filter', val);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 48,
                    child: PopupMenuButton<String>(
                      icon: Icon(Icons.add_circle, color: currentSessionColor, size: 40),
                      padding: EdgeInsets.zero,
                      onSelected: (value) async {
                        final defaultPillarId = pillars.isNotEmpty ? pillars.first.id : 8;
                        bool? result;
                        if (value == 'subject') {
                          result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubjectEditPage(pillarId: defaultPillarId),
                            ),
                          );
                        } else if (value == 'collection') {
                          result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubjectEditPage(pillarId: defaultPillarId, isCollectionMode: true),
                            ),
                          );
                        } else if (value == 'folder') {
                          result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SubjectEditPage(pillarId: defaultPillarId, isFolderMode: true),
                            ),
                          );
                        }
                        if (result == true) _loadDashboard();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'subject',
                          child: ListTile(
                            leading: const Icon(Icons.description, color: Colors.orange),
                            title: Text(context.t('add_subject')),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'collection',
                          child: ListTile(
                            leading: const Icon(Icons.collections, color: Colors.blue),
                            title: Text(context.t('add_collection')),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'folder',
                          child: ListTile(
                            leading: const Icon(Icons.folder, color: Colors.amber),
                            title: Text(context.t('add_folder')),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                child: isSmall 
                  ? Column(children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: context.t('search_subjects'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, value, _) {
                              return value.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        _applySearch();
                                      },
                                    )
                                  : const SizedBox.shrink();
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                        ),
                        onChanged: (_) => _applySearch(),
                      ),
                      const SizedBox(height: 12),
                      filterRow,
                    ])
                  : Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: context.t('search_subjects'),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, value, _) {
                                return value.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          _applySearch();
                                        },
                                      )
                                    : const SizedBox.shrink();
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            filled: true,
                            fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                          ),
                          onChanged: (_) => _applySearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(flex: 5, child: filterRow),
                    ]),
              );
            },
          ),
          slivers: _isLoading
            ? [const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))]
            : [
                if (_allMatchingSubjects.isEmpty && _allDashboardFolders.isEmpty && _allMatchingCollections.isEmpty)
                  const SliverFillRemaining(child: Center(child: Text('No subjects found')))
                else if (isSearching)
                  SliverPadding(
                    padding: EdgeInsets.zero,
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final subject = _filteredSubjects[index];
                        final pillar = pillars.firstWhere((p) => p.id == subject.pillarId);
                        return _SubjectListTile(
                          subject: subject,
                          pillar: pillar,
                          languageCode: _currentTestingLang,
                          initialAgeFilter: _selectedAgeFilter,
                          initialCollectionFilter: _collectionFilter,
                          onChanged: _loadDashboard,
                        );
                      }, childCount: _filteredSubjects.length),
                    ),
                  )
                else
                  SliverLayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.crossAxisExtent < 600 ? 1 : 2;
                      return SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                          childAspectRatio: crossAxisCount == 1 ? 1.8 : 1.4,
                        ),
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final pillar = activePillars[index];
                          final myId = _authService.currentUser?.serverId;

                          // 1. Calculate total items in this pillar that belong to the SELECTED CATEGORY
                          final pillarCategoryTotal = _allDashboardSubjects.where((s) {
                            if (s.pillarId != pillar.id) return false;
                            if (_collectionFilter == 'mine') return s.ownerId == myId;
                            if (_collectionFilter == 'public') return s.isPublic;
                            if (_collectionFilter == 'favorites') return s.isOnDashboard;
                            return true; // 'all'
                          }).length + _allDashboardCollections.where((c) {
                            if (c.pillarId != pillar.id) return false;
                            if (_collectionFilter == 'mine') return c.ownerId == myId;
                            if (_collectionFilter == 'public') return c.isPublic;
                            if (_collectionFilter == 'favorites') return true;
                            return true; // 'all'
                          }).length;

                          // 2. Matching count (filtered by Category + Age + Search)
                          final pillarMatchingSubjects = _allMatchingSubjects.where((s) => s.pillarId == pillar.id).toList();
                          final pillarMatchingCollections = _allMatchingCollections.where((c) => c.pillarId == pillar.id).toList();
                          final matchingCount = pillarMatchingSubjects.length + pillarMatchingCollections.length;
                          
                          final folderCount = _allDashboardFolders.where((f) => f.pillarId == pillar.id).length;

                          // 3. Only show "X of Y" if the user is further filtering by Age or Search
                          final bool isFilteringBeyondCategory = _selectedAgeFilter != 'all' || _searchController.text.isNotEmpty;

                          return _PillarGridTile(
                            pillar: pillar,
                            subjectCount: matchingCount,
                            totalSubjectCount: pillarCategoryTotal,
                            showComparison: isFilteringBeyondCategory,
                            folderCount: folderCount,
                            languageCode: _currentTestingLang,
                            onTap: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => PillarSubjectsPage(
                                  pillar: pillar,
                                  subjects: pillarMatchingSubjects,
                                  collections: pillarMatchingCollections,
                                  languageCode: _currentTestingLang,
                                  initialAgeFilter: _selectedAgeFilter,
                                  initialCollectionFilter: _collectionFilter,
                                )),
                              );
                              if (result is Map) {
                                setState(() {
                                  _selectedAgeFilter = result['ageFilter'] ?? _selectedAgeFilter;
                                  _collectionFilter = result['collectionFilter'] ?? _collectionFilter;
                                });
                                if (result['hasUpdated'] == true) _loadDashboard(); else _applySearch();
                              }
                            },
                          );
                        }, childCount: activePillars.length),
                      );
                    },
                  ),
              ],
        );
      },
    );
  }

  Widget _buildCompactDropdown({required String value, required Map<String, String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, size: 20),
          style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
          items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SubjectListTile extends StatelessWidget {
  final SubjectModel subject;
  final Pillar pillar;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;
  final VoidCallback? onChanged;

  const _SubjectListTile({required this.subject, required this.pillar, required this.languageCode, required this.initialAgeFilter, required this.initialCollectionFilter, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor();
    final cardCount = subject.cardCount; // Corrected to use simplified model
    final isOwner = subject.ownerId == getIt<AuthService>().currentUser?.serverId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final cards = await CardService().getCardsBySubject(subject.id);
          if (context.mounted) {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectLandingPage(subject: subject, cards: cards, languageCode: languageCode)));
            if (result == true) onChanged?.call();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: pillarColor.withValues(alpha: 0.2), width: 1.5)),
          child: Row(children: [
            Icon(pillar.getIconData(), color: pillarColor),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(subject.getName(languageCode), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Row(
                children: [
                  Text('$cardCount ${context.plural('card', cardCount)}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  if (!isOwner && subject.ownerName != null) ...[
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        subject.ownerName!,
                        style: TextStyle(color: pillarColor.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
            ])),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
        ),
      ),
    );
  }
}

class _CollectionListTile extends StatelessWidget {
  final CollectionModel collection;
  final Pillar pillar;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;
  final VoidCallback? onChanged;

  const _CollectionListTile({
    required this.collection,
    required this.pillar,
    required this.languageCode,
    required this.initialAgeFilter,
    required this.initialCollectionFilter,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor();
    final isOwner = collection.ownerId == getIt<AuthService>().currentUser?.serverId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final cards = await CardService().getCollectionCards(collection.subjectIds);
          if (context.mounted) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubjectLandingPage(
                  collection: collection,
                  cards: cards.map((sc) => sc.card).toList(),
                  languageCode: languageCode,
                ),
              ),
            );
            if (result == true) onChanged?.call();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pillarColor.withValues(alpha: 0.2), width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_motion, color: pillarColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.getName(languageCode),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Row(
                      children: [
                        Text(
                          '${collection.subjectIds.length} ${context.plural('subject', collection.subjectIds.length)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        if (!isOwner && collection.ownerName != null) ...[
                          const SizedBox(width: 8),
                          Text('•', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              collection.ownerName!,
                              style: TextStyle(color: pillarColor.withValues(alpha: 0.7), fontSize: 14, fontWeight: FontWeight.w500),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillarGridTile extends StatelessWidget {
  final Pillar pillar;
  final int subjectCount;
  final int totalSubjectCount;
  final bool showComparison;
  final int folderCount;
  final String languageCode;
  final VoidCallback onTap;

  const _PillarGridTile({
    required this.pillar,
    required this.subjectCount,
    required this.totalSubjectCount,
    this.showComparison = false,
    required this.folderCount,
    required this.languageCode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor();
    final bool isEmpty = subjectCount == 0 && folderCount == 0;
    return Opacity(
      opacity: isEmpty ? 0.5 : 1.0,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: isEmpty ? 1 : 4,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [pillarColor, pillarColor.withValues(alpha: 0.8)])),
            child: Stack(children: [
              Positioned(right: -20, bottom: -20, child: Icon(pillar.getIconData(), size: 120, color: Colors.white.withValues(alpha: 0.15))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(pillar.getIconData(), color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Text(pillar.getTranslatedName(languageCode), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.1))),
                  ]),
                  const SizedBox(height: 12),
                  Text(pillar.getTranslatedDescription(languageCode), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                  const Spacer(),
                  Text(
                    (!showComparison || subjectCount == totalSubjectCount) 
                      ? '$subjectCount ${context.plural('subject', subjectCount)}' 
                      : '$subjectCount / $totalSubjectCount ${context.plural('subject', totalSubjectCount)}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, fontWeight: subjectCount > 0 ? FontWeight.bold : FontWeight.normal),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class PillarSubjectsPage extends StatefulWidget {
  final Pillar pillar;
  final List<SubjectModel> subjects;
  final List<CollectionModel> collections;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;

  const PillarSubjectsPage({super.key, required this.pillar, required this.subjects, required this.collections, required this.languageCode, required this.initialAgeFilter, required this.initialCollectionFilter});

  @override
  State<PillarSubjectsPage> createState() => _PillarSubjectsPageState();
}

class _PillarSubjectsPageState extends State<PillarSubjectsPage> {
  final _searchController = TextEditingController();
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();

  late List<SubjectModel> _allSubjects;
  late List<FolderModel> _allFolders;
  late List<CollectionModel> _allCollections;
  List<SubjectModel> _filteredSubjects = [];
  List<SubjectModel> _matchingSubjectsRecursive = [];
  List<CollectionModel> _filteredCollections = [];
  List<CollectionModel> _matchingCollectionsRecursive = [];
  List<FolderModel> _filteredFolders = [];
  bool _isLoading = true;
  bool _hasUpdated = false;
  late String _selectedAgeFilter;
  late String _collectionFilter;

  @override
  void initState() {
    super.initState();
    _selectedAgeFilter = widget.initialAgeFilter;
    _collectionFilter = widget.initialCollectionFilter;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final subjects = await _cardService.getSubjectsByPillar(widget.pillar.id, rootOnly: false);
    final collections = await _cardService.getCollectionsByPillar(widget.pillar.id, rootOnly: false);
    
    final myFolders = await _cardService.getFoldersByPillar(widget.pillar.id);
    final foreignFolderIds = {
      ...subjects.where((s) => s.folderId != null).map((s) => s.folderId!),
      ...collections.where((c) => c.folderId != null).map((c) => c.folderId!),
    }.where((fid) => !myFolders.any((f) => f.id == fid)).toList();
    
    final List<FolderModel> allFolders = [...myFolders];
    if (foreignFolderIds.isNotEmpty) {
      final foreignFolders = await _cardService.getFoldersByIds(foreignFolderIds);
      allFolders.addAll(foreignFolders);
    }

    if (mounted) {
      setState(() { _allSubjects = subjects; _allFolders = allFolders; _allCollections = collections; _applyFilters(); _isLoading = false; });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final myId = _authService.currentUser?.serverId;
    setState(() {
      _matchingSubjectsRecursive = _allSubjects.where((s) {
        final matchesName = s.getName(widget.languageCode).toLowerCase().contains(query);
        final matchesAge = _selectedAgeFilter == 'all' || s.ageGroup == _selectedAgeFilter;
        bool matchesCollection = true;
        if (_collectionFilter == 'mine') {
          matchesCollection = s.ownerId == myId;
        } else if (_collectionFilter == 'public') {
          matchesCollection = s.isPublic;
        } else {
          // 'favorites' (Dashboard)
          matchesCollection = s.isOnDashboard;
        }
        return matchesName && matchesAge && matchesCollection;
      }).toList();

      _matchingCollectionsRecursive = _allCollections.where((c) {
        final matchesName = c.getName(widget.languageCode).toLowerCase().contains(query);
        bool matchesCollection = true;
        if (_collectionFilter == 'mine') {
          matchesCollection = c.ownerId == myId;
        } else if (_collectionFilter == 'public') {
          matchesCollection = c.isPublic;
        } else {
          // 'favorites' (Dashboard)
          matchesCollection = true;
        }
        return matchesName && matchesCollection;
      }).toList();

      final availableFolderIds = _allFolders.map((f) => f.id).toSet();

      _filteredSubjects = _matchingSubjectsRecursive.where((s) => s.folderId == null || !availableFolderIds.contains(s.folderId)).toList();
      _filteredCollections = _matchingCollectionsRecursive.where((c) => c.folderId == null || !availableFolderIds.contains(c.folderId)).toList();

      _filteredFolders = _allFolders.where((f) {
        final matchesQuery = f.getName(widget.languageCode).toLowerCase().contains(query);
        final hasMatchingContent = _matchingSubjectsRecursive.any((s) => s.folderId == f.id) || 
                                 _matchingCollectionsRecursive.any((c) => c.folderId == f.id);
        
        if (hasMatchingContent) return true;
        if (_collectionFilter == 'mine' || _collectionFilter == 'all') {
          return f.ownerId == myId && matchesQuery;
        }
        return false;
      }).toList();

      _filteredFolders.sort((a, b) => a.getName(widget.languageCode).toLowerCase().compareTo(b.getName(widget.languageCode).toLowerCase()));
      _filteredSubjects.sort((a, b) => a.getName(widget.languageCode).toLowerCase().compareTo(b.getName(widget.languageCode).toLowerCase()));
      _filteredCollections.sort((a, b) => a.getName(widget.languageCode).toLowerCase().compareTo(b.getName(widget.languageCode).toLowerCase()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final pillarColor = widget.pillar.getColor();
    const appBarColor = Colors.white;
    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {},
          child: AlioloScrollablePage(
            title: Text(widget.pillar.getTranslatedName(widget.languageCode), style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold)),
            appBarColor: pillarColor,
            actions: [
              IconButton(icon: const Icon(Icons.arrow_back, color: appBarColor), onPressed: () => Navigator.pop(context, {'hasUpdated': _hasUpdated, 'ageFilter': _selectedAgeFilter, 'collectionFilter': _collectionFilter})),
            ],
            fixedBody: LayoutBuilder(builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              final filterRow = Row(children: [
                Expanded(child: _buildCompactDropdown(value: _collectionFilter, items: {'favorites': context.t('filter_dashboard'), 'mine': context.t('filter_my_subjects'), 'public': context.t('filter_public')}, onChanged: (val) { if (val != null) setState(() { _collectionFilter = val; _applyFilters(); }); })),
                const SizedBox(width: 8),
                Expanded(child: _buildCompactDropdown(value: _selectedAgeFilter, items: {'all': context.t('age_all'), '0_6': context.t('age_0_6'), '7_14': context.t('age_7_14'), '15_plus': context.t('age_15_plus')}, onChanged: (val) { if (val != null) setState(() { _selectedAgeFilter = val; _applyFilters(); }); })),
                const SizedBox(width: 8),
                SizedBox(width: 48, child: PopupMenuButton<String>(
                  icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
                  padding: EdgeInsets.zero,
                  onSelected: (value) async {
                    bool? result;
                    if (value == 'subject') result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: widget.pillar.id, initialAgeGroup: _selectedAgeFilter)));
                    else if (value == 'collection') result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: widget.pillar.id, isCollectionMode: true, initialAgeGroup: _selectedAgeFilter)));
                    else if (value == 'folder') result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: widget.pillar.id, isFolderMode: true)));
                    if (result == true) { _loadData(); _hasUpdated = true; }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'subject', child: ListTile(leading: Icon(Icons.description, color: pillarColor), title: Text(context.t('add_subject')), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'collection', child: ListTile(leading: Icon(Icons.auto_awesome_motion, color: pillarColor), title: Text(context.t('add_collection')), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'folder', child: ListTile(leading: Icon(Icons.folder, color: pillarColor), title: Text(context.t('add_folder')), contentPadding: EdgeInsets.zero)),
                  ],
                )),
              ]);
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                child: isSmall 
                  ? Column(children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: context.t('search_subjects'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, value, _) {
                              return value.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        _applyFilters();
                                      },
                                    )
                                  : const SizedBox.shrink();
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                        ),
                        onChanged: (_) => _applyFilters(),
                      ),
                      const SizedBox(height: 12),
                      filterRow,
                    ])
                  : Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: context.t('search_subjects'),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, value, _) {
                                return value.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          _applyFilters();
                                        },
                                      )
                                    : const SizedBox.shrink();
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            filled: true,
                            fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                          ),
                          onChanged: (_) => _applyFilters(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(flex: 5, child: filterRow),
                    ]),
              );
            }),
            slivers: [
              if (_isLoading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_filteredFolders.isEmpty && _filteredSubjects.isEmpty && _filteredCollections.isEmpty) const SliverFillRemaining(child: Center(child: Text('No items found')))
              else SliverPadding(
                padding: const EdgeInsets.only(bottom: 32),
                sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                  if (index < _filteredFolders.length) {
                    final folder = _filteredFolders[index];
                    final matchingInFolder = _matchingSubjectsRecursive.where((s) => s.folderId == folder.id).length +
                                           _matchingCollectionsRecursive.where((c) => c.folderId == folder.id).length;
                    return _FolderListTile(
                      folder: folder, matchingCount: matchingInFolder, totalCount: folder.childCount, pillar: widget.pillar, languageCode: widget.languageCode, initialAgeFilter: _selectedAgeFilter, initialCollectionFilter: _collectionFilter, onChanged: _loadData,
                      onFilterChanged: (age, coll) { setState(() { _selectedAgeFilter = age; _collectionFilter = coll; _applyFilters(); }); },
                    );
                  }
                  int collIndex = index - _filteredFolders.length;
                  if (collIndex < _filteredCollections.length) {
                    final collection = _filteredCollections[collIndex];
                    return _CollectionListTile(collection: collection, pillar: widget.pillar, languageCode: widget.languageCode, initialAgeFilter: _selectedAgeFilter, initialCollectionFilter: _collectionFilter, onChanged: _loadData);
                  }
                  int subIndex = collIndex - _filteredCollections.length;
                  final subject = _filteredSubjects[subIndex];
                  return _SubjectListTile(subject: subject, pillar: widget.pillar, languageCode: widget.languageCode, initialAgeFilter: _selectedAgeFilter, initialCollectionFilter: _collectionFilter, onChanged: _loadData);
                }, childCount: _filteredFolders.length + _filteredCollections.length + _filteredSubjects.length)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactDropdown({required String value, required Map<String, String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withValues(alpha: 0.5))),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, isExpanded: true, icon: const Icon(Icons.arrow_drop_down, size: 20),
        style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      )),
    );
  }
}

class FolderPage extends StatefulWidget {
  final FolderModel folder;
  final Pillar pillar;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;

  const FolderPage({super.key, required this.folder, required this.pillar, required this.languageCode, required this.initialAgeFilter, required this.initialCollectionFilter});

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  final _searchController = TextEditingController();
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();

  List<SubjectModel> _allSubjects = [];
  List<CollectionModel> _allCollections = [];
  List<SubjectModel> _filteredSubjects = [];
  List<CollectionModel> _filteredCollections = [];
  bool _isLoading = true;
  late String _selectedAgeFilter;
  late String _collectionFilter;
  bool _hasUpdated = false;

  @override
  void initState() {
    super.initState();
    _selectedAgeFilter = widget.initialAgeFilter;
    _collectionFilter = widget.initialCollectionFilter;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await _cardService.getSubjectsByPillar(widget.pillar.id, folderId: widget.folder.id);
    final colResults = await _cardService.getCollectionsByPillar(widget.pillar.id, folderId: widget.folder.id);
    if (mounted) setState(() { _allSubjects = results; _allCollections = colResults; _applyFilters(); _isLoading = false; });
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final myId = _authService.currentUser?.serverId;
    setState(() {
      _filteredSubjects = _allSubjects.where((s) {
        final matchesName = s.getName(widget.languageCode).toLowerCase().contains(query);
        final matchesAge = _selectedAgeFilter == 'all' || s.ageGroup == _selectedAgeFilter;
        bool matchesCollection = true;
        if (_collectionFilter == 'mine') matchesCollection = s.ownerId == myId;
        else if (_collectionFilter == 'public') matchesCollection = s.isPublic;
        else {
          // Dashboard
          matchesCollection = s.isOnDashboard;
        }
        return matchesName && matchesAge && matchesCollection;
      }).toList();

      _filteredCollections = _allCollections.where((c) {
        final matchesName = c.getName(widget.languageCode).toLowerCase().contains(query);
        bool matchesCollection = true;
        if (_collectionFilter == 'mine') matchesCollection = c.ownerId == myId;
        else if (_collectionFilter == 'public') matchesCollection = c.isPublic;
        else {
          // Dashboard
          matchesCollection = true;
        }
        return matchesName && matchesCollection;
      }).toList();

      _filteredSubjects.sort((a, b) => a.getName(widget.languageCode).toLowerCase().compareTo(b.getName(widget.languageCode).toLowerCase()));
      _filteredCollections.sort((a, b) => a.getName(widget.languageCode).toLowerCase().compareTo(b.getName(widget.languageCode).toLowerCase()));
    });
  }

  @override
  Widget build(BuildContext context) {
    final pillarColor = widget.pillar.getColor();
    const appBarColor = Colors.white;
    final isOwner = widget.folder.ownerId == _authService.currentUser?.serverId;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {},
          child: AlioloScrollablePage(
            title: Text(widget.folder.getName(widget.languageCode), style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold)),
            appBarColor: pillarColor,
            actions: [
              IconButton(icon: const Icon(Icons.arrow_back, color: appBarColor), onPressed: () => Navigator.pop(context, {'hasUpdated': _hasUpdated, 'ageFilter': _selectedAgeFilter, 'collectionFilter': _collectionFilter})),
              if (isOwner) ...[
                IconButton(icon: const Icon(Icons.edit, color: appBarColor), onPressed: () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(existingFolder: widget.folder, isFolderMode: true)));
                  if (result == true) { _loadData(); _hasUpdated = true; }
                }),
                IconButton(icon: const Icon(Icons.delete, color: appBarColor), onPressed: () async {
                  final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(context.t('delete_folder')), content: const Text('Are you sure you want to delete this folder?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t('cancel'))), TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(context.t('delete')))]));
                  if (confirmed == true && mounted) {
                    try {
                      await _cardService.deleteFolder(widget.folder.id);
                      if (mounted) Navigator.pop(context, {'hasUpdated': true, 'ageFilter': _selectedAgeFilter, 'collectionFilter': _collectionFilter});
                    } catch (e) {
                      if (e.toString().contains('folder_not_empty') && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('folder_not_empty_msg') ?? 'Cannot delete folder: it is not empty')));
                      }
                    }
                  }
                }),
              ],
              IconButton(icon: const Icon(Icons.feedback, color: appBarColor), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FeedbackPage(folderId: widget.folder.id, contextTitle: widget.folder.getName(widget.languageCode), appBarColor: pillarColor)))),
            ],
            fixedBody: LayoutBuilder(builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              final filterRow = Row(children: [
                Expanded(child: _buildCompactDropdown(value: _collectionFilter, items: {'favorites': context.t('filter_dashboard'), 'mine': context.t('filter_my_subjects'), 'public': context.t('filter_public')}, onChanged: (val) { if (val != null) setState(() { _collectionFilter = val; _applyFilters(); }); })),
                const SizedBox(width: 8),
                Expanded(child: _buildCompactDropdown(value: _selectedAgeFilter, items: {'all': context.t('age_all'), '0_6': context.t('age_0_6'), '7_14': context.t('age_7_14'), '15_plus': context.t('age_15_plus')}, onChanged: (val) { if (val != null) setState(() { _selectedAgeFilter = val; _applyFilters(); }); })),
                const SizedBox(width: 8),
                SizedBox(width: 48, child: PopupMenuButton<String>(
                  icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
                  padding: EdgeInsets.zero,
                  onSelected: (value) async {
                    bool? result;
                    if (value == 'subject') result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: widget.pillar.id, folderId: widget.folder.id, initialAgeGroup: _selectedAgeFilter)));
                    else if (value == 'collection') result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: widget.pillar.id, folderId: widget.folder.id, isCollectionMode: true, initialAgeGroup: _selectedAgeFilter)));
                    if (result == true) { _loadData(); _hasUpdated = true; }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'subject', child: ListTile(leading: Icon(Icons.description, color: pillarColor), title: Text(context.t('add_subject')), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'collection', child: ListTile(leading: Icon(Icons.auto_awesome_motion, color: pillarColor), title: Text(context.t('add_collection')), contentPadding: EdgeInsets.zero)),
                  ],
                )),
              ]);
              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                child: isSmall 
                  ? Column(children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: context.t('search_subjects'),
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, value, _) {
                              return value.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        _applyFilters();
                                      },
                                    )
                                  : const SizedBox.shrink();
                            },
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                        ),
                        onChanged: (_) => _applyFilters(),
                      ),
                      const SizedBox(height: 12),
                      filterRow,
                    ])
                  : Row(children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: context.t('search_subjects'),
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, value, _) {
                                return value.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          _searchController.clear();
                                          _applyFilters();
                                        },
                                      )
                                    : const SizedBox.shrink();
                              },
                            ),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            filled: true,
                            fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                          ),
                          onChanged: (_) => _applyFilters(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(flex: 5, child: filterRow),
                    ]),
              );
            }),
            slivers: [
              if (_isLoading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_filteredSubjects.isEmpty && _filteredCollections.isEmpty) const SliverFillRemaining(child: Center(child: Text('No subjects found')))
              else SliverPadding(padding: const EdgeInsets.only(bottom: 32), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                if (index < _filteredCollections.length) {
                  final collection = _filteredCollections[index];
                  return _CollectionListTile(collection: collection, pillar: widget.pillar, languageCode: widget.languageCode, initialAgeFilter: _selectedAgeFilter, initialCollectionFilter: _collectionFilter, onChanged: () { _loadData(); _hasUpdated = true; });
                }
                final subject = _filteredSubjects[index - _filteredCollections.length];
                return _SubjectListTile(subject: subject, pillar: widget.pillar, languageCode: widget.languageCode, initialAgeFilter: _selectedAgeFilter, initialCollectionFilter: _collectionFilter, onChanged: () { _loadData(); _hasUpdated = true; });
              }, childCount: _filteredCollections.length + _filteredSubjects.length))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactDropdown({required String value, required Map<String, String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withValues(alpha: 0.5))),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: value, isExpanded: true, icon: const Icon(Icons.arrow_drop_down, size: 20),
        style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      )),
    );
  }
}

class _FolderListTile extends StatelessWidget {
  final FolderModel folder;
  final int matchingCount;
  final int totalCount;
  final Pillar pillar;
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;
  final VoidCallback? onChanged;
  final Function(String age, String collection)? onFilterChanged;

  const _FolderListTile({required this.folder, required this.matchingCount, required this.totalCount, required this.pillar, required this.languageCode, required this.initialAgeFilter, required this.initialCollectionFilter, this.onChanged, this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor();
    final bool isEmpty = matchingCount == 0;
    return Opacity(
      opacity: isEmpty ? 0.5 : 1.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => FolderPage(folder: folder, pillar: pillar, languageCode: languageCode, initialAgeFilter: initialAgeFilter, initialCollectionFilter: initialCollectionFilter)));
            if (result is Map) {
              onFilterChanged?.call(result['ageFilter'] ?? initialAgeFilter, result['collectionFilter'] ?? initialCollectionFilter);
              if (result['hasUpdated'] == true) onChanged?.call();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: pillarColor.withValues(alpha: 0.2), width: 1.5)),
            child: Row(children: [
              Icon(Icons.folder, color: pillarColor),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(folder.getName(languageCode), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(matchingCount == totalCount ? '$totalCount ${context.plural('subject', totalCount)}' : '$matchingCount / $totalCount ${context.plural('subject', totalCount)}', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: matchingCount > 0 ? FontWeight.bold : FontWeight.normal)),
              ])),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ]),
          ),
        ),
      ),
    );
  }
}
