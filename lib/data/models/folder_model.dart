import 'dart:convert';
import 'content_item.dart';

class FolderModel implements ContentItem {
  @override
  final String id;
  @override
  final int pillarId;
  @override
  final String ownerId;
  @override
  String? ownerName;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final int childCount;

  /// Base name
  @override
  final String name;
  /// Map of language code to its specific name.
  @override
  final Map<String, String> names;

  // Folders do not have descriptions in the database
  @override
  String get description => '';
  @override
  Map<String, String> get descriptions => const {};
  
  @override
  ContentType get type => ContentType.folder;
  @override
  String? get folderId => null; 
  @override
  bool get isOnDashboard => false;

  FolderModel({
    required this.id,
    required this.pillarId,
    required this.ownerId,
    this.ownerName,
    required this.createdAt,
    required this.updatedAt,
    this.childCount = 0,
    required this.name,
    this.names = const {},
  });

  factory FolderModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> namesMap = {};
    final dynamic rawNames = json['names'];
    if (rawNames is Map) {
      namesMap = Map<String, String>.from(rawNames);
    } else if (rawNames is String && rawNames.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNames);
        if (decoded is Map) {
          namesMap = Map<String, String>.from(decoded);
        }
      } catch (_) {}
    }

    // Fallback migration logic in app just in case (legacy data in localized_data)
    String baseName = json['name'] ?? '';

    if (baseName.isEmpty && json['localized_data'] != null) {
      var locData = json['localized_data'];
      Map<String, dynamic> locMap = {};
      if (locData is Map) {
        locMap = Map<String, dynamic>.from(locData);
      } else if (locData is String && locData.isNotEmpty) {
        try { locMap = Map<String, dynamic>.from(jsonDecode(locData)); } catch (_) {}
      }
      final global = locMap['global'];
      if (global is Map) {
        baseName = global['name'] ?? '';
      }
      locMap.forEach((k, v) {
        if (k != 'global' && v is Map) {
          if (namesMap[k] == null) namesMap[k] = v['name'] ?? '';
        }
      });
    }

    final Map<String, dynamic>? profile = json['profiles'];
    int count = 0;
    if (json['subjects'] is List) {
      final subjectsList = json['subjects'] as List;
      if (subjectsList.isNotEmpty && subjectsList.first is Map && subjectsList.first['count'] != null) {
        count += (subjectsList.first['count'] as num).toInt();
      } else {
        count += subjectsList.length;
      }
    } else if (json['subjects'] is Map && json['subjects']['count'] != null) {
      count += (json['subjects']['count'] as num).toInt();
    }
    if (json['collections'] is List) {
      final collectionsList = json['collections'] as List;
      if (collectionsList.isNotEmpty && collectionsList.first is Map && collectionsList.first['count'] != null) {
        count += (collectionsList.first['count'] as num).toInt();
      } else {
        count += collectionsList.length;
      }
    } else if (json['collections'] is Map && json['collections']['count'] != null) {
      count += (json['collections']['count'] as num).toInt();
    }

    return FolderModel(
      id: json['id'],
      pillarId: json['pillar_id'] ?? 1,
      ownerId: json['owner_id'] ?? '',
      ownerName: profile != null ? profile['username'] : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      childCount: count,
      name: baseName,
      names: namesMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pillar_id': pillarId,
      'owner_id': ownerId,
      'name': name,
      'names': names,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static String capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String getName(String langCode) {
    final lc = langCode.toLowerCase();
    if (names.containsKey(lc) && names[lc]!.isNotEmpty) {
      return capitalizeFirst(names[lc]!);
    }
    return capitalizeFirst(name.isNotEmpty ? name : 'Unnamed Folder');
  }

  @override
  String getDescription(String langCode) => '';
}
