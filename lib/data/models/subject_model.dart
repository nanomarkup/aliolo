class LocalizedSubjectData {
  final String? name;
  final String? description;

  LocalizedSubjectData({this.name, this.description});

  factory LocalizedSubjectData.fromJson(Map<String, dynamic> json) {
    return LocalizedSubjectData(
      name: json['name'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    };
  }
}

class SubjectModel {
  final String id;
  final int pillarId;
  final String ownerId;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int cardCount;
  final List<Map<String, dynamic>>? rawCards;
  final String? ownerName;
  final String ageGroup;
  final String? parentId;
  final String type; // 'standard', 'folder', 'math_engine'
  final int childCount;

  bool isOnDashboard;

  bool get isCounting =>
      id == '68232807-b9cd-4cff-872c-c398444f85e2' ||
      id == 'c3548727-65f4-4e0c-939c-56135b4eb543';

  bool get isAddition =>
      id == 'de04da1c-9820-4e61-ae6b-bc7ed07eeb93' ||
      id == '5e81da1f-f92c-44d2-b3cd-f921d05425df';

  bool get isEditableType => cardCount == 0 && childCount == 0;

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

  int get maxOperand {
    if (id == 'de04da1c-9820-4e61-ae6b-bc7ed07eeb93') return 5;
    if (id == '5e81da1f-f92c-44d2-b3cd-f921d05425df') return 10;
    if (id == 'ce04da1c-9820-4e61-ae6b-bc7ed07eeb93') return 10;
    if (id == 'f59a0f9c-5d6d-4f2d-b426-eb9ca6bf2782') return 20;
    return 0;
  }

  bool matchesNameRecursive(String query, String langCode, List<SubjectModel> allSubjects) {
    if (query.isEmpty) return true;
    if (getName(langCode).toLowerCase().contains(query.toLowerCase())) return true;

    if (type == 'folder') {
      final children = allSubjects.where((s) => s.parentId == id);
      for (var child in children) {
        if (child.matchesNameRecursive(query, langCode, allSubjects)) return true;
      }
    }
    return false;
  }

  bool matchesAgeGroupRecursive(String targetAge, List<SubjectModel> allSubjects) {
    if (targetAge == 'all') return true;
    if (ageGroup == targetAge) return true;

    if (type == 'folder') {
      final children = allSubjects.where((s) => s.parentId == id);
      for (var child in children) {
        if (child.matchesAgeGroupRecursive(targetAge, allSubjects)) return true;
      }
    }
    return false;
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
    this.ageGroup = 'all',
    this.localizedData = const {},
    this.parentId,
    this.type = 'standard',
    this.childCount = 0,
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

  String getName(String langCode) {
    return _getInherited(langCode, (d) => d.name) ?? 'Unnamed Subject';
  }

  String getDescription(String langCode) {
    return _getInherited(langCode, (d) => d.description) ?? '';
  }

  // Legacy support for code that expects a single string name
  String get name => getName('en');

  int getCardCountForLanguage(String langCode) {
    if (rawCards == null) return cardCount;
    final lang = langCode.toLowerCase();
    return rawCards!.where((c) {
      final locData = c['localized_data'] as Map<String, dynamic>?;
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
      'parent_id': parentId,
      'type': type,
    };
  }

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? allCards =
        json['cards'] is List ? json['cards'] : null;
    final List<dynamic>? activeCards =
        allCards?.where((c) => c['is_deleted'] != true).toList();

    final Map<String, dynamic>? profile = json['profiles'];

    final Map<String, dynamic> locMap = json['localized_data'] ?? {};
    Map<String, LocalizedSubjectData> localized = locMap.map(
      (key, value) => MapEntry(
        key.toLowerCase(),
        LocalizedSubjectData.fromJson(value as Map<String, dynamic>),
      ),
    );

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

    // Try to get child count from children relation if present
    int count = 0;
    if (json['children'] is List) {
      final childrenList = json['children'] as List;
      if (childrenList.isNotEmpty && childrenList.first is Map && childrenList.first['count'] != null) {
        count = childrenList.first['count'];
      } else {
        count = childrenList.length;
      }
    } else if (json['children'] is Map && json['children']['count'] != null) {
      count = json['children']['count'];
    }

    return SubjectModel(
      id: json['id'],
      pillarId: json['pillar_id'] ?? 1,
      ownerId: json['owner_id'] ?? '',
      ownerName: profile != null ? profile['username'] : null,
      isPublic: json['is_public'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      cardCount:
          activeCards != null ? activeCards.length : (json['card_count'] ?? 0),
      rawCards:
          activeCards != null
              ? List<Map<String, dynamic>>.from(activeCards)
              : null,
      ageGroup: json['age_group'] ?? 'all',
      localizedData: localized,
      parentId: json['parent_id'],
      type: json['type'] ?? 'standard',
      childCount: count,
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
    );
  }
}
