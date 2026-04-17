import 'dart:convert';
import 'content_item.dart';

class SubjectModel implements ContentItem {
  @override
  final String id;
  @override
  final int pillarId;
  @override
  final String ownerId;
  final bool isPublic;
  final DateTime createdAt;
  @override
  final DateTime updatedAt;
  int cardCount;
  final List<Map<String, dynamic>>? rawCards;
  @override
  String? ownerName;
  final String ageGroup;
  @override
  final String? folderId;
  final String typeStr; // renamed from type to avoid conflict with ContentItem.type
  final List<String> linkedSubjectIds;

  @override
  ContentType get type => ContentType.subject;

  bool isOnDashboard;

  /// Base name
  final String name;
  /// Map of language code to its specific name.
  final Map<String, String> names;
  /// Base description
  final String description;
  /// Map of language code to its specific description.
  final Map<String, String> descriptions;

  String get _normalizedName => name.trim().toLowerCase();

  bool get isAddition => _normalizedName.startsWith('addition');

  bool get isEditableType => cardCount == 0;

  bool get isSubtraction => _normalizedName.startsWith('subtraction');

  bool get isMultiplication =>
      _normalizedName.startsWith('multiply') ||
      _normalizedName.startsWith('multiplication');

  bool get isDivision =>
      _normalizedName.startsWith('divide') ||
      _normalizedName.startsWith('division');

  bool get isColors => _normalizedName == 'colors';

  bool get isCounting => _normalizedName == 'counting';

  bool get isMath =>
      isAddition ||
      isSubtraction ||
      isMultiplication ||
      isDivision;

  int get maxOperand {
    final nameLower = name.toLowerCase();
    final trailingNumber = RegExp(r'(\d+)\s*$').firstMatch(nameLower);
    if (isMultiplication || isDivision) {
      return int.tryParse(trailingNumber?.group(1) ?? '') ?? 0;
    }
    if (isAddition || isSubtraction) {
      if (nameLower.contains('0-5')) return 5;
      if (nameLower.contains('0-10')) return 10;
      if (nameLower.contains('11-20')) return 20;
    }
    return 0;
  }

  SubjectModel({
    required this.id,
    required this.pillarId,
    required this.ownerId,
    this.ownerName,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    this.cardCount = 0,
    this.rawCards,
    this.isOnDashboard = false,
    this.ageGroup = '15_plus',
    required this.name,
    this.names = const {},
    required this.description,
    this.descriptions = const {},
    this.folderId,
    this.typeStr = 'standard',
    this.linkedSubjectIds = const [],
  });

  static String capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String getName(String langCode) {
    final lc = langCode.toLowerCase();
    if (names.containsKey(lc) && names[lc]!.isNotEmpty) {
      return capitalizeFirst(names[lc]!);
    }
    return capitalizeFirst(name.isNotEmpty ? name : 'Unnamed Subject');
  }

  String getDescription(String langCode) {
    final lc = langCode.toLowerCase();
    if (descriptions.containsKey(lc) && descriptions[lc]!.isNotEmpty) {
      return capitalizeFirst(descriptions[lc]!);
    }
    return capitalizeFirst(description);
  }

  int getCardCountForLanguage(String langCode) {
    if (rawCards == null) return cardCount;
    final lang = langCode.toLowerCase();
    return rawCards!.where((c) {
      var rawLoc = c['localized_data'];
      Map<String, dynamic>? locData;
      if (rawLoc is Map) {
        locData = Map<String, dynamic>.from(rawLoc);
      } else if (rawLoc is String && rawLoc.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawLoc);
          if (decoded is Map) {
            locData = Map<String, dynamic>.from(decoded);
          }
        } catch (_) {}
      }

      if (locData == null) return false;

      final specificData = locData[lang] as Map<String, dynamic>?;
      final globalData = locData['global'] as Map<String, dynamic>?;
      final enData = locData['en'] as Map<String, dynamic>?;

      return (specificData != null &&
              (specificData['prompt'] != null ||
                  specificData['answer'] != null)) ||
          (globalData != null &&
              (globalData['prompt'] != null || globalData['answer'] != null)) ||
          (enData != null &&
              (enData['prompt'] != null || enData['answer'] != null));
    }).length;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pillar_id': pillarId,
      'owner_id': ownerId,
      'is_public': isPublic,
      'age_group': ageGroup,
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'name': name,
      'names': names,
      'description': description,
      'descriptions': descriptions,
      'folder_id': folderId,
      if (typeStr != 'standard') 'type': typeStr,
      if (linkedSubjectIds.isNotEmpty) 'linked_subject_ids': linkedSubjectIds,
    };
  }

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? allCards =
        json['cards'] is List ? json['cards'] : null;

    final Map<String, dynamic>? profile = json['profiles'] ?? json['profiles!fk_subjects_owner'];

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

    return SubjectModel(
      id: json['id'],
      pillarId: json['pillar_id'] ?? 1,
      ownerId: json['owner_id'] ?? '',
      ownerName: profile != null ? profile['username'] : null,
      isPublic: json['is_public'] == true || json['is_public'] == 1,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      cardCount:
          allCards != null ? allCards.length : (json['card_count'] ?? 0),
      rawCards:
          allCards != null
              ? List<Map<String, dynamic>>.from(allCards)
              : null,
      ageGroup: json['age_group'] ?? '15_plus',
      name: baseName,
      names: namesMap,
      description: baseDesc,
      descriptions: descriptionsMap,
      folderId: json['folder_id'],
      typeStr: json['type'] ?? 'standard',
      linkedSubjectIds: List<String>.from(json['linked_subject_ids'] ?? []),
      isOnDashboard: json['is_on_dashboard'] == true || json['is_on_dashboard'] == 1,
    );
  }

  factory SubjectModel.empty() {
    return SubjectModel(
      id: '',
      pillarId: 1,
      ownerId: '',
      isPublic: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      typeStr: 'standard',
      linkedSubjectIds: [],
      name: '',
      description: '',
    );
  }
}
