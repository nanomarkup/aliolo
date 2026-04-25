import 'package:aliolo/data/models/content_item.dart';
import 'package:aliolo/data/models/folder_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/collection_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/core/di/service_locator.dart';

class DiscoveryFilters {
  final String query;
  final String ageGroup;
  final String collectionFilter; // 'favorites', 'mine', 'public', 'all'
  final int? pillarId;
  final String? folderId;
  final bool rootOnly;

  DiscoveryFilters({
    this.query = '',
    this.ageGroup = 'all',
    this.collectionFilter = 'all',
    this.pillarId,
    this.folderId,
    this.rootOnly = false,
  });

  DiscoveryFilters copyWith({
    String? query,
    String? ageGroup,
    String? collectionFilter,
    int? pillarId,
    String? folderId,
    bool? rootOnly,
  }) {
    return DiscoveryFilters(
      query: query ?? this.query,
      ageGroup: ageGroup ?? this.ageGroup,
      collectionFilter: collectionFilter ?? this.collectionFilter,
      pillarId: pillarId ?? this.pillarId,
      folderId: folderId ?? this.folderId,
      rootOnly: rootOnly ?? this.rootOnly,
    );
  }
}

class DiscoveryEngine {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();

  static List<Pillar> filterVisiblePillars(
    List<Pillar> allPillars,
    List<ContentItem> visibleContent,
  ) {
    final visiblePillarIds =
        visibleContent
            .where(isPillarContent)
            .map((item) => item.pillarId)
            .toSet();
    return allPillars
        .where((pillar) => visiblePillarIds.contains(pillar.id))
        .toList();
  }

  static bool isPillarContent(ContentItem item) {
    return item is SubjectModel || item is CollectionModel;
  }

  static Map<int, int> countPillarContent(List<ContentItem> items) {
    final counts = <int, int>{};
    for (final item in items.where(isPillarContent)) {
      counts[item.pillarId] = (counts[item.pillarId] ?? 0) + 1;
    }
    return counts;
  }

  static bool shouldShowFolder(
    FolderModel folder,
    List<ContentItem> items, {
    required String collectionFilter,
    required String? myId,
  }) {
    final hasMatchingContent = items.any((item) => item.folderId == folder.id);
    if (hasMatchingContent) return true;
    return collectionFilter == 'mine' && folder.ownerId == myId;
  }

  Future<List<ContentItem>> getContent(DiscoveryFilters filters, String langCode) async {
    final items = await getRawContent(filters);
    return applyFiltersAndSort(items, filters, langCode);
  }

  Future<List<ContentItem>> getRawContent(DiscoveryFilters filters) async {
    List<ContentItem> items = [];

    if (filters.pillarId != null) {
      final subjects = await _cardService.getSubjectsByPillar(
        filters.pillarId!,
        folderId: filters.folderId,
        rootOnly: filters.rootOnly,
        filter: filters.collectionFilter,
      );
      final collections = await _cardService.getCollectionsByPillar(
        filters.pillarId!,
        folderId: filters.folderId,
        rootOnly: filters.rootOnly,
        filter: filters.collectionFilter,
      );
      final folders =
          filters.folderId == null
              ? await _cardService.getFoldersByPillar(filters.pillarId!)
              : <FolderModel>[];

      items.addAll(subjects);
      items.addAll(collections);
      items.addAll(folders);
    } else {
      // For dashboard or global view, fetch content based on the source filter
      final subjects = await _cardService.getSubjectsByPillar(
        -1, // Dummy or handled by backend to mean "all pillars" if pillarId is omitted
        rootOnly: false,
        filter: filters.collectionFilter,
      );
      final collections = await _cardService.getAllCollections(
        rootOnly: false,
        filter: filters.collectionFilter,
      );
      final folders = await _cardService.getAllFolders();

      items.addAll(subjects);
      items.addAll(collections);
      items.addAll(folders);
    }

    return items;
  }

  List<ContentItem> applyFiltersAndSort(List<ContentItem> items, DiscoveryFilters filters, String langCode) {
    final myId = _authService.currentUser?.serverId;
    final query = filters.query.toLowerCase();
    
    print('DiscoveryEngine.applyFiltersAndSort: items=${items.length}, filter=${filters.collectionFilter}, myId=$myId, lang=$langCode');

    // 1. First pass: Basic filtering (Age, Collection Category, Search Query)
    var filtered = items.where((item) {
      // Search match
      final nameMatch = item.getName(langCode).toLowerCase().contains(query);
      
      // Collection Filter
      bool collectionMatch = true;
      if (filters.collectionFilter == 'mine') {
        // "My Subjects" should return all items owned by the user, regardless of visibility.
        collectionMatch = item.ownerId == myId;
      } else if (filters.collectionFilter == 'public') {
        if (item is SubjectModel) {
          collectionMatch = item.isPublic;
        } else if (item is CollectionModel) {
          collectionMatch = item.isPublic;
        } else {
          collectionMatch = true; // Folders are public by default (navigation only)
        }
      } else if (filters.collectionFilter == 'favorites') {
        if (item is SubjectModel) {
          collectionMatch = item.isOnDashboard;
        } else if (item is CollectionModel) {
          collectionMatch = item.isOnDashboard;
        } else {
          collectionMatch = true; 
        }
      }

      final match = nameMatch && collectionMatch;
      if (items.length < 20 && !match) {
         // print('DiscoveryEngine: item ${item.id} (${item.getName(langCode)}) filtered out: nameMatch=$nameMatch, collectionMatch=$collectionMatch');
      }

      // Age Filter (for subjects and collections)
      bool ageMatch = true;
      if (filters.ageGroup != 'all') {
        if (item is SubjectModel) {
          ageMatch = item.ageGroup == filters.ageGroup;
        } else if (item is CollectionModel) {
          ageMatch = item.ageGroup == filters.ageGroup;
        }
      }

      return match && ageMatch;
    }).toList();

    print('DiscoveryEngine.applyFiltersAndSort: filtered=${filtered.length}');

    // 2. Structural Filtering (Pillar/Folder hierarchy)
    // We only apply structural filtering if we are NOT searching.
    // If we are searching, we return everything matching.
    if (query.isNotEmpty) return filtered;

    // To allow the UI to calculate folder counts, we provide a structured view
    // while keeping all items available for the UI if needed.
    // We will do the final structural pass in getVisibleContent instead of here.
    return filtered;
  }

  /// Helper to get only the items that should be visible at a specific level (root or folder)
  List<ContentItem> getVisibleContent(
    List<ContentItem> items,
    String langCode, {
    String? folderId,
    bool rootOnly = false,
    String collectionFilter = 'all',
    String? myId,
    String query = '',
  }) {
    List<ContentItem> visible;

    if (query.isNotEmpty) {
      visible = items; // If searching, show everything
    } else if (folderId != null) {
      visible = items.where((item) => item.folderId == folderId).toList();
    } else if (rootOnly) {
      final folderIds = items.whereType<FolderModel>().map((f) => f.id).toSet();
      visible =
          items.where((item) {
            if (item is FolderModel) return true;
            return item.folderId == null || !folderIds.contains(item.folderId);
          }).toList();
    } else {
      visible = items;
    }

    // Apply the source filter locally as well to ensure UI consistency
    if (collectionFilter != 'all') {
      visible =
          visible.where((item) {
            if (item is FolderModel) return true; // Folders are handled by special logic below
            if (collectionFilter == 'mine') return item.ownerId == myId;
            if (collectionFilter == 'favorites') return item.isOnDashboard;
            if (collectionFilter == 'public') {
              if (item is SubjectModel) return item.isPublic;
              if (item is CollectionModel) return item.isPublic;
            }
            return true;
          }).toList();
    }

    // Folders should only stay visible when they still have matching content.
    // The one exception is `mine`, where empty owned folders remain visible for management.
    if (folderId == null && query.isEmpty) {
      visible = visible.where((item) {
        if (item is! FolderModel) return true;
        return shouldShowFolder(
          item,
          items,
          collectionFilter: collectionFilter,
          myId: myId,
        );
      }).toList();
    }

    // Sorting
    visible.sort((a, b) {
      if (a.type != b.type) {
        if (a.type == ContentType.folder) return -1;
        if (b.type == ContentType.folder) return 1;
        if (a.type == ContentType.collection) return -1;
        if (b.type == ContentType.collection) return 1;
      }
      return a.getName(langCode).toLowerCase().compareTo(b.getName(langCode).toLowerCase());
    });

    return visible;
  }
}
