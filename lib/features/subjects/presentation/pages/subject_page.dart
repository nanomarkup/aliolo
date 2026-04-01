import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
import 'package:aliolo/features/documentation/presentation/pages/documentation_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_landing_page.dart';
import 'package:aliolo/features/management/presentation/pages/subject_edit_page.dart';
import 'package:aliolo/data/services/feedback_service.dart';
import 'package:aliolo/data/models/content_item.dart';
import 'package:aliolo/data/services/discovery_engine.dart';
import 'package:aliolo/features/feedback/presentation/pages/feedback_page.dart';

class SubjectPage extends StatefulWidget {
  const SubjectPage({super.key});

  @override
  State<SubjectPage> createState() => _SubjectPageState();
}

class _SubjectPageState extends State<SubjectPage> {
  final _cardService = getIt<CardService>();
  final _discoveryEngine = getIt<DiscoveryEngine>();
  final _searchController = TextEditingController();
  final _authService = getIt<AuthService>();

  String _currentTestingLang = 'en';
  bool _isLangInitialized = false;

  List<ContentItem> _allContent = [];
  List<ContentItem> _matchingContent = [];
  List<ContentItem> _filteredContent = [];
  bool _isLoading = true;

  DiscoveryFilters _filters = DiscoveryFilters(
    ageGroup: 'all',
    collectionFilter: 'favorites',
    rootOnly: true,
  );

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
      final validCollectionFilters = {'all', 'favorites', 'mine', 'public'};
      final validatedCollectionFilter = validCollectionFilters.contains(savedCollectionFilter) 
          ? savedCollectionFilter 
          : 'favorites';

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
        
        _filters = _filters.copyWith(
          ageGroup: savedAgeFilter,
          collectionFilter: validatedCollectionFilter,
        );
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
    
    final content = await _discoveryEngine.getRawContent(_filters);

    if (mounted) {
      final Set<String> detectedLangs = {};
      for (var item in content) {
        detectedLangs.addAll(item.localizedData.keys.map((k) => k.toLowerCase()));
        if (item is SubjectModel && item.rawCards != null) {
          for (var c in item.rawCards!) {
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
        _allContent = content;
        if (!hasSavedCollection && _allContent.whereType<SubjectModel>().where((s) => s.isOnDashboard).isEmpty) {
          _filters = _filters.copyWith(collectionFilter: 'public');
        }
        _applySearch();
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    setState(() {
      _filters = _filters.copyWith(
        query: _searchController.text,
      );
      _matchingContent = _discoveryEngine.applyFiltersAndSort(_allContent, _filters, _currentTestingLang);
      _filteredContent = _discoveryEngine.getVisibleContent(
        _matchingContent,
        _currentTestingLang,
        rootOnly: true,
        collectionFilter: _filters.collectionFilter,
        myId: _authService.currentUser?.serverId,
        query: _filters.query,
      );
    });
  }

  Future<void> _navigateToSubject(dynamic result) async {
    if (result == null || result == true) return;
    
    final lang = TranslationService().currentLocale.languageCode;
    
    if (result is SubjectModel) {
      final cards = await _cardService.getCardsBySubject(result.id);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectLandingPage(
              subject: result,
              cards: cards,
              languageCode: lang,
            ),
          ),
        );
        _loadDashboard();
      }
    } else if (result is CollectionModel) {
      final cards = await _cardService.getCollectionCards(result.subjectIds);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectLandingPage(
              collection: result,
              cards: cards.map((sc) => sc.card).toList(),
              languageCode: lang,
            ),
          ),
        );
        _loadDashboard();
      }
    }
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
          _filteredContent.any((item) => item.pillarId == p.id)
        ).toList();

        final activeCodes = getIt<TestingLanguageService>().activeLanguageCodes.map((l) => l.toLowerCase()).toSet();
        if (!activeCodes.contains(_currentTestingLang)) {
          activeCodes.add(_currentTestingLang);
        }

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            final shouldExit = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(context.t('exit_confirm_title')),
                content: Text(context.t('exit_confirm_msg')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.t('cancel'))),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(context.t('exit')),
                  ),
                ],
              ),
            );
            if (shouldExit == true && context.mounted) {
              SystemNavigator.pop();
            }
          },
          child: AlioloScrollablePage(
            title: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currentTestingLang,
                dropdownColor: currentSessionColor,
                icon: const Icon(Icons.language, color: appBarColor, size: 20),
                style: const TextStyle(
                  color: appBarColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                // This ensures the popup is wide even if the button is narrow
                menuWidth: 250,
                isExpanded: false,
                selectedItemBuilder: (context) {
                  final isSmall = MediaQuery.of(context).size.width < 500;
                  return activeCodes.map((l) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isSmall
                            ? l.toUpperCase()
                            : getIt<TestingLanguageService>().getLanguageName(l),
                        style: const TextStyle(color: appBarColor),
                      ),
                    );
                  }).toList();
                },
                items:
                    activeCodes.map((l) {
                      return DropdownMenuItem(
                        value: l,
                        child: Text(
                          getIt<TestingLanguageService>().getLanguageName(l),
                          style: const TextStyle(color: Colors.white),
                        ),
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
              if (_authService.currentUser?.showDocumentation ?? true)
                IconButton(
                  icon: const Icon(Icons.help_outline, color: appBarColor),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentationPage())),
                ),
            ],
            fixedBody: LayoutBuilder(
              builder: (context, constraints) {
                final isSmall = constraints.maxWidth < 600;
                final filterRow = Row(
                  children: [
                    Expanded(
                      child: _buildCompactDropdown(
                        value: _filters.collectionFilter,
                        items: {
                          'all': context.t('filter_all') ?? 'All',
                          'favorites': context.t('filter_dashboard'),
                          'mine': context.t('filter_my_subjects'),
                          'public': context.t('filter_public'),
                        },
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() { 
                              _filters = _filters.copyWith(collectionFilter: val); 
                              _applySearch(); 
                            });
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('last_collection_filter', val);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildCompactDropdown(
                        value: _filters.ageGroup,
                        items: {
                          'all': context.t('age_all'),
                          '0_6': context.t('age_0_6'),
                          '7_14': context.t('age_7_14'),
                          '15_plus': context.t('age_15_plus'),
                        },
                        onChanged: (val) async {
                          if (val != null) {
                            setState(() { 
                              _filters = _filters.copyWith(ageGroup: val); 
                              _applySearch(); 
                            });
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
                          dynamic result;
                          if (value == 'subject') {
                            result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: defaultPillarId)));
                          } else if (value == 'collection') {
                            result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: defaultPillarId, isCollectionMode: true)));
                          } else if (value == 'folder') {
                            result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: defaultPillarId, isFolderMode: true)));
                          }
                          
                          if (result == true) {
                            _loadDashboard();
                          } else if (result != null) {
                            await _navigateToSubject(result);
                          }
                        },
                        itemBuilder: (context) => [
                          PopupMenuItem(value: 'subject', child: ListTile(leading: const Icon(Icons.description, color: Colors.orange), title: Text(context.t('add_subject')), contentPadding: EdgeInsets.zero)),
                          PopupMenuItem(value: 'collection', child: ListTile(leading: const Icon(Icons.collections, color: Colors.blue), title: Text(context.t('add_collection')), contentPadding: EdgeInsets.zero)),
                          PopupMenuItem(value: 'folder', child: ListTile(leading: const Icon(Icons.folder, color: Colors.amber), title: Text(context.t('add_folder')), contentPadding: EdgeInsets.zero)),
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
                                return value.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _applySearch(); }) : const SizedBox.shrink();
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
                                  return value.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _applySearch(); }) : const SizedBox.shrink();
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
                  if (_allContent.isEmpty)
                    const SliverFillRemaining(child: Center(child: Text('No subjects found')))
                  else if (isSearching)
                    SliverPadding(
                      padding: EdgeInsets.zero,
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final item = _filteredContent[index];
                          final pillar = pillars.firstWhere((p) => p.id == item.pillarId, orElse: () => pillars.first);
                          if (item is FolderModel) {
                            final myId = _authService.currentUser?.serverId;
                            final folderCategoryTotal = _allContent.where((e) {
                              if (e.folderId != item.id) return false;
                              if (_filters.collectionFilter == 'mine') return e.ownerId == myId;
                              if (_filters.collectionFilter == 'public') {
                                if (e is SubjectModel) return e.isPublic;
                                if (e is CollectionModel) return e.isPublic;
                                return false;
                              }
                              if (_filters.collectionFilter == 'favorites') return e.isOnDashboard;
                              return true;
                            }).length;
                            final matchingInFolder = _matchingContent.where((e) => e.folderId == item.id).length;
                            return _FolderListTile(folder: item, matchingCount: matchingInFolder, totalCount: folderCategoryTotal, pillar: pillar, languageCode: _currentTestingLang, initialAgeFilter: _filters.ageGroup, initialCollectionFilter: _filters.collectionFilter, onChanged: _loadDashboard);
                          } else if (item is CollectionModel) {
                            return _CollectionListTile(collection: item, pillar: pillar, languageCode: _currentTestingLang, initialAgeFilter: _filters.ageGroup, initialCollectionFilter: _filters.collectionFilter, onChanged: _loadDashboard, onFavoriteChanged: () { setState(() { item.isOnDashboard = !item.isOnDashboard; }); });
                          } else if (item is SubjectModel) {
                            return _SubjectListTile(subject: item, pillar: pillar, languageCode: _currentTestingLang, initialAgeFilter: _filters.ageGroup, initialCollectionFilter: _filters.collectionFilter, onChanged: _loadDashboard, onFavoriteChanged: () { setState(() { item.isOnDashboard = !item.isOnDashboard; }); });
                          }
                          return const SizedBox.shrink();
                        }, childCount: _filteredContent.length),
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
                            final pillarCategoryTotal = _allContent.where((item) {
                              if (item.pillarId != pillar.id) return false;
                              if (item is FolderModel) return false;
                              if (_filters.collectionFilter == 'mine') return item.ownerId == myId;
                              if (_filters.collectionFilter == 'public') {
                                if (item is SubjectModel) return item.isPublic;
                                if (item is CollectionModel) return item.isPublic;
                                return false;
                              }
                              if (_filters.collectionFilter == 'favorites') return item.isOnDashboard;
                              return true;
                            }).length;
                            final matchingCount = _discoveryEngine.applyFiltersAndSort(_allContent.where((e) => e.pillarId == pillar.id).toList(), _filters.copyWith(rootOnly: false), _currentTestingLang).where((e) => e is! FolderModel).length;
                            final folderCount = _allContent.whereType<FolderModel>().where((f) => f.pillarId == pillar.id).length;
                            final bool isFilteringBeyondCategory = _filters.ageGroup != 'all' || _searchController.text.isNotEmpty;
                            return _PillarGridTile(
                              pillar: pillar, subjectCount: matchingCount, totalSubjectCount: pillarCategoryTotal, showComparison: isFilteringBeyondCategory, folderCount: folderCount, languageCode: _currentTestingLang,
                              onTap: () async {
                                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => PillarSubjectsPage(pillar: pillar, languageCode: _currentTestingLang, initialAgeFilter: _filters.ageGroup, initialCollectionFilter: _filters.collectionFilter)));
                                if (result is Map) {
                                  setState(() { _filters = _filters.copyWith(ageGroup: result['ageFilter'] ?? _filters.ageGroup, collectionFilter: result['collectionFilter'] ?? _filters.collectionFilter); });
                                  if (result['hasUpdated'] == true) _loadDashboard(); else _applySearch();
                                }
                              },
                            );
                          }, childCount: activePillars.length),
                        );
                      },
                    ),
                ],
          ),
        );
      },
    );
  }

  Widget _buildCompactDropdown({required String value, required Map<String, String> items, required ValueChanged<String?> onChanged}) {
    final validatedValue = items.containsKey(value) ? value : items.keys.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withValues(alpha: 0.5))),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: validatedValue, isExpanded: true, icon: const Icon(Icons.arrow_drop_down, size: 20),
        style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      )),
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
  final VoidCallback? onFavoriteChanged;

  const _SubjectListTile({required this.subject, required this.pillar, required this.languageCode, required this.initialAgeFilter, required this.initialCollectionFilter, this.onChanged, this.onFavoriteChanged});

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor(getIt<ThemeService>().isDarkMode);
    final cardCount = subject.cardCount;
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
                    if (subject.ownerName == 'Aliolo') Icon(Icons.verified, color: Colors.grey[600], size: 16)
                    else Flexible(child: Text(subject.ownerName!, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  ],
                ],
              ),
            ])),
            IconButton(
              icon: Icon(subject.isOnDashboard ? Icons.star : Icons.star_border, color: subject.isOnDashboard ? Colors.amber : Colors.grey),
              onPressed: () async {
                try {
                  await getIt<CardService>().toggleSubjectOnDashboard(subject.id, !subject.isOnDashboard);
                  if (onFavoriteChanged != null) onFavoriteChanged!(); else onChanged?.call();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating favorite: $e')));
                }
              },
            ),
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
  final VoidCallback? onFavoriteChanged;

  const _CollectionListTile({required this.collection, required this.pillar, required this.languageCode, required this.initialAgeFilter, required this.initialCollectionFilter, this.onChanged, this.onFavoriteChanged});

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor(getIt<ThemeService>().isDarkMode);
    final isOwner = collection.ownerId == getIt<AuthService>().currentUser?.serverId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () async {
          final cards = await CardService().getCollectionCards(collection.subjectIds);
          if (context.mounted) {
            final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectLandingPage(collection: collection, cards: cards.map((sc) => sc.card).toList(), languageCode: languageCode)));
            if (result == true) onChanged?.call();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: pillarColor.withValues(alpha: 0.2), width: 1.5)),
          child: Row(children: [
            Icon(Icons.auto_awesome_motion, color: pillarColor),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(collection.getName(languageCode), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Row(
                children: [
                  Text('${collection.subjectIds.length} ${context.plural('subject', collection.subjectIds.length)}', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                  if (!isOwner && collection.ownerName != null) ...[
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                    const SizedBox(width: 8),
                    if (collection.ownerName == 'Aliolo') Icon(Icons.verified, color: Colors.grey[600], size: 16)
                    else Flexible(child: Text(collection.ownerName!, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                  ],
                ],
              ),
            ])),
            IconButton(
              icon: Icon(collection.isOnDashboard ? Icons.star : Icons.star_border, color: collection.isOnDashboard ? Colors.amber : Colors.grey),
              onPressed: () async {
                try {
                  await getIt<CardService>().toggleCollectionOnDashboard(collection.id, !collection.isOnDashboard);
                  if (onFavoriteChanged != null) onFavoriteChanged!(); else onChanged?.call();
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating favorite: $e')));
                }
              },
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ]),
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

  const _PillarGridTile({required this.pillar, required this.subjectCount, required this.totalSubjectCount, this.showComparison = false, required this.folderCount, required this.languageCode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor(getIt<ThemeService>().isDarkMode);
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
  final String languageCode;
  final String initialAgeFilter;
  final String initialCollectionFilter;

  const PillarSubjectsPage({super.key, required this.pillar, required this.languageCode, required this.initialAgeFilter, required this.initialCollectionFilter});

  @override
  State<PillarSubjectsPage> createState() => _PillarSubjectsPageState();
}

class _PillarSubjectsPageState extends State<PillarSubjectsPage> {
  final _searchController = TextEditingController();
  final _cardService = getIt<CardService>();
  final _discoveryEngine = getIt<DiscoveryEngine>();

  List<ContentItem> _allContent = [];
  List<ContentItem> _matchingContent = [];
  List<ContentItem> _filteredContent = [];
  bool _isLoading = true;
  bool _hasUpdated = false;
  late DiscoveryFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = DiscoveryFilters(
      pillarId: widget.pillar.id,
      ageGroup: widget.initialAgeFilter,
      collectionFilter: widget.initialCollectionFilter,
      rootOnly: false,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final content = await _discoveryEngine.getRawContent(_filters);
    if (mounted) setState(() { _allContent = content; _applySearch(); _isLoading = false; });
  }

  void _applySearch() {
    setState(() {
      _filters = _filters.copyWith(query: _searchController.text);
      _matchingContent = _discoveryEngine.applyFiltersAndSort(_allContent, _filters, widget.languageCode);

      _filteredContent = _discoveryEngine.getVisibleContent(
        _matchingContent,
        widget.languageCode,
        folderId: _filters.folderId,
        rootOnly: _filters.folderId == null,
        collectionFilter: _filters.collectionFilter,
        myId: getIt<AuthService>().currentUser?.serverId,
        query: _filters.query,
      );
    });
  }

  Future<void> _navigateToSubject(dynamic result) async {
    if (result == null || result == true) return;

    final lang = TranslationService().currentLocale.languageCode;

    if (result is SubjectModel) {
      final cards = await _cardService.getCardsBySubject(result.id);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectLandingPage(
              subject: result,
              cards: cards,
              languageCode: lang,
            ),
          ),
        );
        _loadData();
      }
    } else if (result is CollectionModel) {
      final cards = await _cardService.getCollectionCards(result.subjectIds);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectLandingPage(
              collection: result,
              cards: cards.map((sc) => sc.card).toList(),
              languageCode: lang,
            ),
          ),
        );
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {    final pillarColor = widget.pillar.getColor(getIt<ThemeService>().isDarkMode);
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
              IconButton(icon: const Icon(Icons.arrow_back, color: appBarColor), onPressed: () => Navigator.pop(context, {'hasUpdated': _hasUpdated, 'ageFilter': _filters.ageGroup, 'collectionFilter': _filters.collectionFilter})),
            ],
            fixedBody: LayoutBuilder(builder: (context, constraints) {
              final isSmall = constraints.maxWidth < 600;
              final filterRow = Row(children: [
                Expanded(child: _buildCompactDropdown(value: _filters.collectionFilter, items: {'all': context.t('filter_all') ?? 'All', 'favorites': context.t('filter_dashboard'), 'mine': context.t('filter_my_subjects'), 'public': context.t('filter_public')}, onChanged: (val) { if (val != null) setState(() { _filters = _filters.copyWith(collectionFilter: val); _applySearch(); }); })),
                const SizedBox(width: 8),
                Expanded(child: _buildCompactDropdown(value: _filters.ageGroup, items: {'all': context.t('age_all'), '0_6': context.t('age_0_6'), '7_14': context.t('age_7_14'), '15_plus': context.t('age_15_plus')}, onChanged: (val) { if (val != null) setState(() { _filters = _filters.copyWith(ageGroup: val); _applySearch(); }); })),
                const SizedBox(width: 8),
                SizedBox(width: 48, child: PopupMenuButton<String>(
                  icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
                  padding: EdgeInsets.zero,
                  onSelected: (value) async {
                    dynamic result;
                    if (value == 'subject') result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: widget.pillar.id, initialAgeGroup: _filters.ageGroup)));
                    else if (value == 'collection') result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: widget.pillar.id, isCollectionMode: true, initialAgeGroup: _filters.ageGroup)));
                    else if (value == 'folder') result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: widget.pillar.id, isFolderMode: true)));
                    
                    if (result == true) {
                      _loadData();
                      _hasUpdated = true;
                    } else if (result != null) {
                      _loadData();
                      _hasUpdated = true;
                      await _navigateToSubject(result);
                    }
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
                              return value.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _applySearch(); }) : const SizedBox.shrink();
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
                                return value.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _applySearch(); }) : const SizedBox.shrink();
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
            }),
            slivers: [
              if (_isLoading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_filteredContent.isEmpty) const SliverFillRemaining(child: Center(child: Text('No items found')))
              else SliverPadding(
                padding: const EdgeInsets.only(bottom: 32),
                sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                  final item = _filteredContent[index];
                  final pillar = pillars.firstWhere((p) => p.id == item.pillarId, orElse: () => pillars.first);
                  if (item is FolderModel) {
                    final myId = getIt<AuthService>().currentUser?.serverId;
                    final folderCategoryTotal = _allContent.where((e) {
                      if (e.folderId != item.id) return false;
                      if (_filters.collectionFilter == 'mine') return e.ownerId == myId;
                      if (_filters.collectionFilter == 'public') {
                        if (e is SubjectModel) return e.isPublic;
                        if (e is CollectionModel) return e.isPublic;
                        return false;
                      }
                      if (_filters.collectionFilter == 'favorites') return e.isOnDashboard;
                      return true;
                    }).length;
                    final matchingInFolder = _matchingContent.where((e) => e.folderId == item.id).length;
                    return _FolderListTile(folder: item, matchingCount: matchingInFolder, totalCount: folderCategoryTotal, pillar: pillar, languageCode: widget.languageCode, initialAgeFilter: _filters.ageGroup, initialCollectionFilter: _filters.collectionFilter, onChanged: _loadData, onFilterChanged: (age, coll) { setState(() { _filters = _filters.copyWith(ageGroup: age, collectionFilter: coll); _applySearch(); }); });
                  } else if (item is CollectionModel) {
                    return _CollectionListTile(collection: item, pillar: pillar, languageCode: widget.languageCode, initialAgeFilter: _filters.ageGroup, initialCollectionFilter: _filters.collectionFilter, onChanged: _loadData, onFavoriteChanged: () { setState(() { item.isOnDashboard = !item.isOnDashboard; }); });
                  } else if (item is SubjectModel) {
                    return _SubjectListTile(subject: item, pillar: pillar, languageCode: widget.languageCode, initialAgeFilter: _filters.ageGroup, initialCollectionFilter: _filters.collectionFilter, onChanged: _loadData, onFavoriteChanged: () { setState(() { item.isOnDashboard = !item.isOnDashboard; }); });
                  }
                  return const SizedBox.shrink();
                }, childCount: _filteredContent.length)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactDropdown({required String value, required Map<String, String> items, required ValueChanged<String?> onChanged}) {
    final validatedValue = items.containsKey(value) ? value : items.keys.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withValues(alpha: 0.5))),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: validatedValue, isExpanded: true, icon: const Icon(Icons.arrow_drop_down, size: 20),
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
    final pillarColor = pillar.getColor(getIt<ThemeService>().isDarkMode);
    final bool isEmpty = matchingCount == 0;
    final isOwner = folder.ownerId == getIt<AuthService>().currentUser?.serverId;

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
                Row(
                  children: [
                    Text(matchingCount == totalCount ? '$totalCount ${context.plural('subject', totalCount)}' : '$matchingCount / $totalCount ${context.plural('subject', totalCount)}', style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: matchingCount > 0 ? FontWeight.bold : FontWeight.normal)),
                    if (!isOwner && folder.ownerName != null) ...[
                      const SizedBox(width: 8),
                      Text('•', style: TextStyle(color: Colors.grey[400], fontSize: 14)),
                      const SizedBox(width: 8),
                      if (folder.ownerName == 'Aliolo') Icon(Icons.verified, color: Colors.grey[600], size: 16)
                      else Flexible(child: Text(folder.ownerName!, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    ],
                  ],
                ),
              ])),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ]),
          ),
        ),
      ),
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
  final _discoveryEngine = getIt<DiscoveryEngine>();
  final _authService = getIt<AuthService>();

  List<ContentItem> _allContent = [];
  List<ContentItem> _matchingContent = [];
  List<ContentItem> _filteredContent = [];
  bool _isLoading = true;
  late DiscoveryFilters _filters;
  bool _hasUpdated = false;

  @override
  void initState() {
    super.initState();
    _filters = DiscoveryFilters(
      pillarId: widget.pillar.id,
      folderId: widget.folder.id,
      ageGroup: widget.initialAgeFilter,
      collectionFilter: widget.initialCollectionFilter,
      rootOnly: false,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final content = await _discoveryEngine.getRawContent(_filters);
    if (mounted) setState(() { _allContent = content; _applySearch(); _isLoading = false; });
  }

  void _applySearch() {
    setState(() {
      _filters = _filters.copyWith(query: _searchController.text);
      _matchingContent = _discoveryEngine.applyFiltersAndSort(_allContent, _filters, widget.languageCode);

      _filteredContent = _discoveryEngine.getVisibleContent(
        _matchingContent,
        widget.languageCode,
        folderId: _filters.folderId,
        rootOnly: _filters.folderId == null,
        collectionFilter: _filters.collectionFilter,
        myId: getIt<AuthService>().currentUser?.serverId,
        query: _filters.query,
      );
    });
  }

  Future<void> _navigateToSubject(dynamic result) async {
    if (result == null || result == true) return;

    final lang = TranslationService().currentLocale.languageCode;

    if (result is SubjectModel) {
      final cards = await _cardService.getCardsBySubject(result.id);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectLandingPage(
              subject: result,
              cards: cards,
              languageCode: lang,
            ),
          ),
        );
        _loadData();
      }
    } else if (result is CollectionModel) {
      final cards = await _cardService.getCollectionCards(result.subjectIds);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SubjectLandingPage(
              collection: result,
              cards: cards.map((sc) => sc.card).toList(),
              languageCode: lang,
            ),
          ),
        );
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {    final pillarColor = widget.pillar.getColor(getIt<ThemeService>().isDarkMode);
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
              IconButton(icon: const Icon(Icons.arrow_back, color: appBarColor), onPressed: () => Navigator.pop(context, {'hasUpdated': _hasUpdated, 'ageFilter': _filters.ageGroup, 'collectionFilter': _filters.collectionFilter})),
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
                      if (mounted) Navigator.pop(context, {'hasUpdated': true, 'ageFilter': _filters.ageGroup, 'collectionFilter': _filters.collectionFilter});
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
                Expanded(child: _buildCompactDropdown(value: _filters.collectionFilter, items: {'all': context.t('filter_all') ?? 'All', 'favorites': context.t('filter_dashboard'), 'mine': context.t('filter_my_subjects'), 'public': context.t('filter_public')}, onChanged: (val) { if (val != null) setState(() { _filters = _filters.copyWith(collectionFilter: val); _applySearch(); }); })),
                const SizedBox(width: 8),
                Expanded(child: _buildCompactDropdown(value: _filters.ageGroup, items: {'all': context.t('age_all'), '0_6': context.t('age_0_6'), '7_14': context.t('age_7_14'), '15_plus': context.t('age_15_plus')}, onChanged: (val) { if (val != null) setState(() { _filters = _filters.copyWith(ageGroup: val); _applySearch(); }); })),
                const SizedBox(width: 8),
                SizedBox(width: 48, child: PopupMenuButton<String>(
                  icon: Icon(Icons.add_circle, color: pillarColor, size: 40),
                  padding: EdgeInsets.zero,
                  onSelected: (value) async {
                    dynamic result;
                    if (value == 'subject') result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: widget.pillar.id, folderId: widget.folder.id, initialAgeGroup: _filters.ageGroup)));
                    else if (value == 'collection') result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SubjectEditPage(pillarId: widget.pillar.id, folderId: widget.folder.id, isCollectionMode: true, initialAgeGroup: _filters.ageGroup)));
                    
                    if (result == true) {
                      _loadData();
                      _hasUpdated = true;
                    } else if (result != null) {
                      _loadData();
                      _hasUpdated = true;
                      await _navigateToSubject(result);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'subject', child: ListTile(leading: Icon(Icons.description, color: pillarColor), title: Text(context.t('add_subject')), contentPadding: EdgeInsets.zero)),
                    PopupMenuItem(value: 'collection', child: ListTile(leading: Icon(Icons.auto_awesome_motion, color: pillarColor), title: Text(context.t('add_collection')), contentPadding: EdgeInsets.zero)),
                  ],
                )),
              ]);

              final description = widget.folder.getDescription(widget.languageCode);

              return Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    isSmall 
                      ? Column(children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: context.t('search_subjects'),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _searchController,
                                builder: (context, value, _) {
                                  return value.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _applySearch(); }) : const SizedBox.shrink();
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
                                    return value.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchController.clear(); _applySearch(); }) : const SizedBox.shrink();
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
                  ],
                ),
              );
            }),
            slivers: [
              if (_isLoading) const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (_filteredContent.isEmpty) const SliverFillRemaining(child: Center(child: Text('No subjects found')))
              else SliverPadding(padding: const EdgeInsets.only(bottom: 32), sliver: SliverList(delegate: SliverChildBuilderDelegate((context, index) {
                final item = _filteredContent[index];
                if (item is FolderModel) {
                  final myId = getIt<AuthService>().currentUser?.serverId;
                  final folderCategoryTotal = _allContent.where((e) {
                    if (e.folderId != item.id) return false;
                    if (_filters.collectionFilter == 'mine') return e.ownerId == myId;
                    if (_filters.collectionFilter == 'public') {
                      if (e is SubjectModel) return e.isPublic;
                      if (e is CollectionModel) return e.isPublic;
                      return false;
                    }
                    if (_filters.collectionFilter == 'favorites') return e.isOnDashboard;
                    return true;
                  }).length;
                  final matchingInFolder = _matchingContent.where((e) => e.folderId == item.id).length;
                  return _FolderListTile(folder: item, matchingCount: matchingInFolder, totalCount: folderCategoryTotal, pillar: widget.pillar, languageCode: widget.languageCode, initialAgeFilter: _filters.ageGroup, initialCollectionFilter: _filters.collectionFilter, onChanged: () { _loadData(); _hasUpdated = true; }, onFilterChanged: (age, coll) { setState(() { _filters = _filters.copyWith(ageGroup: age, collectionFilter: coll); _applySearch(); }); });
                } else if (item is CollectionModel) {
                  return _CollectionListTile(collection: item, pillar: widget.pillar, languageCode: widget.languageCode, initialAgeFilter: _filters.ageGroup, initialCollectionFilter: _filters.collectionFilter, onChanged: () { _loadData(); _hasUpdated = true; }, onFavoriteChanged: () { setState(() { item.isOnDashboard = !item.isOnDashboard; _hasUpdated = true; }); });
                } else if (item is SubjectModel) {
                  return _SubjectListTile(subject: item, pillar: widget.pillar, languageCode: widget.languageCode, initialAgeFilter: _filters.ageGroup, initialCollectionFilter: _filters.collectionFilter, onChanged: () { _loadData(); _hasUpdated = true; }, onFavoriteChanged: () { setState(() { item.isOnDashboard = !item.isOnDashboard; _hasUpdated = true; }); });
                }
                return const SizedBox.shrink();
              }, childCount: _filteredContent.length))),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactDropdown({required String value, required Map<String, String> items, required ValueChanged<String?> onChanged}) {
    final validatedValue = items.containsKey(value) ? value : items.keys.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Theme.of(context).cardColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.withValues(alpha: 0.5))),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: validatedValue, isExpanded: true, icon: const Icon(Icons.arrow_drop_down, size: 20),
        style: TextStyle(fontSize: 14, color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87),
        items: items.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))).toList(),
        onChanged: onChanged,
      )),
    );
  }
}
