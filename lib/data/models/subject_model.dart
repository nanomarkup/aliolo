import 'dart:convert';
import 'content_item.dart';

class LocalizedSubjectData {
  final String? name;
  final String? description;
  final Map<String, dynamic> rawData;

  LocalizedSubjectData({
    this.name,
    this.description,
    this.rawData = const {},
  });

  factory LocalizedSubjectData.fromJson(Map<String, dynamic> json) {
    return LocalizedSubjectData(
      name: json['name'],
      description: json['description'],
      rawData: json,
    );
  }

  Map<String, dynamic> toJson() {
    final map = Map<String, dynamic>.from(rawData);
    if (name != null) {
      map['name'] = name;
    } else {
      map.remove('name');
    }
    if (description != null) {
      map['description'] = description;
    } else {
      map.remove('description');
    }
    return map;
  }
}

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

  bool get isCounting =>
      id == '68232807-b9cd-4cff-872c-c398444f85e2' ||
      id == 'c3548727-65f4-4e0c-939c-56135b4eb543';

  bool get isAddition =>
      id == 'de04da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == '5e81da1f-f92c-44d2-b3cd-f921d05425df';

  bool get isEditableType => cardCount == 0;

  bool get isSubtraction =>
      id == 'ce04da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'f59a0f9c-5d6d-4f2d-b426-eb9ca6bf2782';

  bool get isMultiplication =>
      id == 'e104da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'e204da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'e304da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'e404da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'e504da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'e604da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'e704da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'e804da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'e904da1c-9820-4e61-ae6b-bc7ed07eeb93';

  bool get isDivision =>
      id == 'd104da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'd204da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'd304da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'd404da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'd504da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'd604da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'd704da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'd804da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == 'd904da1c-9820-4e61-ae6b-bc7ed07eeb93';

  bool get isNumbers =>
      id == 'bc354f43-f9be-42a9-a7bc-ac400bd5e310' ||
      id == 'cb04da1c-9820-4e61-ae6b-bc7ed07eeb93';

  bool get isColors => id == '0b84447d-3af3-4509-bdf6-c4e7fe822cc7';

  bool get isMath =>
      isCounting ||
      isAddition ||
      isSubtraction ||
      isMultiplication ||
      isDivision ||
      isNumbers;

  int get maxOperand {
    if (id == 'de04da1c-9820-4e61-ae6b-bc7ed07eeb93') return 5;
    if (id == '5e81da1f-f92c-44d2-b3cd-f921d05425df') return 10;
    if (id == 'ce04da1c-9820-4e61-ae6b-bc7ed07eeb93') return 10;
    if (id == 'f59a0f9c-5d6d-4f2d-b426-eb9ca6bf2782') return 20;
    return 0;
  }

  /// Map of language code to its specific data.
  /// Key 'global' is used for fallback assets (if any).
  final Map<String, LocalizedSubjectData> localizedData;

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
    this.localizedData = const {},
    this.folderId,
    this.typeStr = 'standard',
    this.linkedSubjectIds = const [],
  });

  T? _getInherited<T>(String langCode, T? Function(LocalizedSubjectData) getter) {
    final lang = langCode.toLowerCase();
    // 1. Try requested language
    if (localizedData.containsKey(lang)) {
      final val = getter(localizedData[lang]!);
      if (val != null) return val;
    }
    // 2. Try 'global'
    if (localizedData.containsKey('global')) {
      final val = getter(localizedData['global']!);
      if (val != null) return val;
    }
    // 3. Try 'en'
    if (localizedData.containsKey('en')) {
      final val = getter(localizedData['en']!);
      if (val != null) return val;
    }
    // 4. Fallback to any available name
    if (localizedData.isNotEmpty) {
      final val = getter(localizedData.values.first);
      if (val != null) return val;
    }
    return null;
  }

  static String capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String getName(String langCode) {
    final name = _getInherited(langCode, (d) => d.name) ?? 'Unnamed Subject';
    return capitalizeFirst(name);
  }

  String getDescription(String langCode) {
    final desc = _getInherited(langCode, (d) => d.description) ?? '';
    return capitalizeFirst(desc);
  }

  // Legacy support for code that expects a single string name
  String get name => getName('en');

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
      'localized_data': localizedData.map((k, v) => MapEntry(k, v.toJson())),
      'folder_id': folderId,
      if (typeStr != 'standard') 'type': typeStr,
      if (linkedSubjectIds.isNotEmpty) 'linked_subject_ids': linkedSubjectIds,
    };
  }

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? allCards =
        json['cards'] is List ? json['cards'] : null;
    final List<dynamic>? activeCards =
        allCards?.where((c) => c['is_deleted'] != true).toList();

    final Map<String, dynamic>? profile = json['profiles'] ?? json['profiles!fk_subjects_owner'];

    var locData = json['localized_data'];
    Map<String, dynamic> locMap = {};
    if (locData is Map) {
      locMap = Map<String, dynamic>.from(locData);
    } else if (locData is String && locData.isNotEmpty) {
      try {
        locMap = Map<String, dynamic>.from(jsonDecode(locData));
      } catch (_) {}
    }

    Map<String, LocalizedSubjectData> localized = {};
    try {
      locMap.forEach((key, value) {
        if (value is Map) {
          localized[key.toLowerCase()] = LocalizedSubjectData.fromJson(Map<String, dynamic>.from(value));
        }
      });
    } catch (e) {
      print('Error parsing localized_data for subject ${json['id']}: $e');
    }

    // Fallback migration logic in app just in case
    if (localized.isEmpty) {
      final Map<String, String> parsedNames = {};
      final Map<String, String> parsedDescriptions = {};

      if (json['names'] is Map) {
        Map<String, String>.from(
          json['names'],
        ).forEach((k, v) => parsedNames[k] = v);
      }
      if (json['descriptions'] is Map) {
        Map<String, String>.from(
          json['descriptions'],
        ).forEach((k, v) => parsedDescriptions[k] = v);
      }

      final Set<String> allLangs = {
        ...parsedNames.keys,
        ...parsedDescriptions.keys,
      };
      for (var lang in allLangs) {
        localized[lang] = LocalizedSubjectData(
          name: parsedNames[lang],
          description: parsedDescriptions[lang],
        );
      }
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
          activeCards != null ? activeCards.length : (json['card_count'] ?? 0),
      rawCards:
          activeCards != null
              ? List<Map<String, dynamic>>.from(activeCards)
              : null,
      ageGroup: json['age_group'] ?? '15_plus',
      localizedData: localized,
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
    );
  }
}
