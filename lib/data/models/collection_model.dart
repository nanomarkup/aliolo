import 'dart:convert';
import 'subject_model.dart';
import 'content_item.dart';

class CollectionModel implements ContentItem {
  @override
  final String id;
  @override
  final int pillarId;
  @override
  final String? folderId;
  @override
  final String ownerId;
  @override
  String? ownerName;
  final bool isPublic;
  final String ageGroup;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  final List<String> subjectIds;
  bool isOnDashboard;

  /// Base name
  final String name;
  /// Map of language code to its specific name.
  final Map<String, String> names;
  /// Base description
  final String description;
  /// Map of language code to its specific description.
  final Map<String, String> descriptions;

  @override
  ContentType get type => ContentType.collection;

  CollectionModel({
    required this.id,
    required this.pillarId,
    this.folderId,
    required this.ownerId,
    this.ownerName,
    this.isPublic = false,
    this.ageGroup = '15_plus',
    required this.createdAt,
    required this.updatedAt,
    this.subjectIds = const [],
    this.isOnDashboard = false,
    required this.name,
    this.names = const {},
    required this.description,
    this.descriptions = const {},
  });

  factory CollectionModel.fromJson(Map<String, dynamic> json) {
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

    Map<String, String> descriptionsMap = {};
    final dynamic rawDescriptions = json['descriptions'];
    if (rawDescriptions is Map) {
      descriptionsMap = Map<String, String>.from(rawDescriptions);
    } else if (rawDescriptions is String && rawDescriptions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawDescriptions);
        if (decoded is Map) {
          descriptionsMap = Map<String, String>.from(decoded);
        }
      } catch (_) {}
    }

    // Fallback migration logic in app just in case (legacy data in localized_data)
    String baseName = json['name'] ?? '';
    String baseDesc = json['description'] ?? '';

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
        baseDesc = global['description'] ?? '';
      }
      locMap.forEach((k, v) {
        if (k != 'global' && v is Map) {
          if (namesMap[k] == null) namesMap[k] = v['name'] ?? '';
          if (descriptionsMap[k] == null) descriptionsMap[k] = v['description'] ?? '';
        }
      });
    }

    final Map<String, dynamic>? profile = json['profiles'];
    final List<String> subjects = [];
    if (json['collection_items'] is List) {
      for (var item in json['collection_items']) {
        if (item['subject_id'] != null) {
          subjects.add(item['subject_id']);
        }
      }
    }

    return CollectionModel(
      id: json['id'],
      pillarId: json['pillar_id'] ?? 1,
      folderId: json['folder_id'],
      ownerId: json['owner_id'] ?? '',
      ownerName: profile != null ? profile['username'] : null,
      isPublic: json['is_public'] == true || json['is_public'] == 1,
      ageGroup: json['age_group'] ?? '15_plus',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      subjectIds: subjects,
      isOnDashboard: json['is_on_dashboard'] == true || json['is_on_dashboard'] == 1,
      name: baseName,
      names: namesMap,
      description: baseDesc,
      descriptions: descriptionsMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pillar_id': pillarId,
      'folder_id': folderId,
      'owner_id': ownerId,
      'is_public': isPublic,
      'age_group': ageGroup,
      'name': name,
      'names': names,
      'description': description,
      'descriptions': descriptions,
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
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
    return capitalizeFirst(name.isNotEmpty ? name : 'Unnamed Collection');
  }

  String getDescription(String langCode) {
    final lc = langCode.toLowerCase();
    if (descriptions.containsKey(lc) && descriptions[lc]!.isNotEmpty) {
      return capitalizeFirst(descriptions[lc]!);
    }
    return capitalizeFirst(description);
  }
}
