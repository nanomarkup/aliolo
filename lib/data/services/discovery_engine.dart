import 'package:flutter/foundation.dart';
import 'package:aliolo/data/models/content_item.dart';
import 'package:aliolo/data/models/folder_model.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/collection_model.dart';
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

  Future<List<ContentItem>> getContent(DiscoveryFilters filters, String langCode) async {
    final items = await getRawContent(filters);
    return applyFiltersAndSort(items, filters, langCode);
  }

  Future<List<ContentItem>> getRawContent(DiscoveryFilters filters) async {
    List<ContentItem> items = [];

    if (filters.pillarId != null) {
      final subjects = await _cardService.getSubjectsByPillar(filters.pillarId!, folderId: filters.folderId, rootOnly: filters.rootOnly);
      final collections = await _cardService.getCollectionsByPillar(filters.pillarId!, folderId: filters.folderId, rootOnly: filters.rootOnly);
      final folders = filters.folderId == null ? await _cardService.getFoldersByPillar(filters.pillarId!) : <FolderModel>[];
      
      items.addAll(subjects);
      items.addAll(collections);
      items.addAll(folders);
    } else {
      // For dashboard or global view, fetch all accessible content
      final subjects = await _cardService.getDashboardSubjects();
      final collections = await _cardService.getAllCollections(rootOnly: false);
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

      // Age Filter (for subjects and collections)
      bool ageMatch = true;
      if (filters.ageGroup != 'all') {
        if (item is SubjectModel) {
          ageMatch = item.ageGroup == filters.ageGroup;
        } else if (item is CollectionModel) {
          ageMatch = item.ageGroup == filters.ageGroup;
        }
      }

      return nameMatch && collectionMatch && ageMatch;
    }).toList();

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
  List<ContentItem> getVisibleContent(List<ContentItem> items, String langCode, {String? folderId, bool rootOnly = false, String collectionFilter = 'all', String? myId, String query = ''}) {
    List<ContentItem> visible;
    
    if (query.isNotEmpty) {
      visible = items; // If searching, show everything
    } else if (folderId != null) {
      visible = items.where((item) => item.folderId == folderId).toList();
    } else if (rootOnly) {
      final folderIds = items.whereType<FolderModel>().map((f) => f.id).toSet();
      visible = items.where((item) {
        if (item is FolderModel) return true;
        return item.folderId == null || !folderIds.contains(item.folderId);
      }).toList();
    } else {
      visible = items;
    }

    // Special folder logic: Only show folders if they have matching content or belong to user
    if (folderId == null && query.isEmpty) {
      final matchingFolderIds = items.where((e) => e.folderId != null).map((e) => e.folderId!).toSet();
      visible = visible.where((item) {
        if (item is! FolderModel) return true;
        final hasMatchingContent = matchingFolderIds.contains(item.id);
        bool shouldShowEmptyFolder = false;
        if (collectionFilter == 'mine' || collectionFilter == 'all') {
          shouldShowEmptyFolder = item.ownerId == myId;
        }
        return hasMatchingContent || shouldShowEmptyFolder;
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
