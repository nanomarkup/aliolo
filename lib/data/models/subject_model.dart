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

  bool isOnDashboard;

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
  });

  /// Helper to get an attribute with smart inheritance
  T? _getInherited<T>(String lang, T? Function(LocalizedSubjectData) getter) {
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
    final lang = langCode.toLowerCase();
    return _getInherited(lang, (d) => d.name) ?? 'Unnamed Subject';
  }

  String getDescription(String langCode) {
    final lang = langCode.toLowerCase();
    return _getInherited(lang, (d) => d.description) ?? '';
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
        key,
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
