class SubjectModel {
  final String id;
  final Map<String, String> names;
  final int pillarId;
  final Map<String, String> descriptions;
  final String ownerId;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int cardCount;
  final List<Map<String, dynamic>>? rawCards;
  final String? ownerName;

  final String ageGroup;

  bool isOnDashboard;

  SubjectModel({
    required this.id,
    required this.names,
    required this.pillarId,
    this.descriptions = const {},
    required this.ownerId,
    this.ownerName,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    this.cardCount = 0,
    this.rawCards,
    this.isOnDashboard = false,
    this.ageGroup = 'advanced',
  });

  String getName(String langCode) {
    return names[langCode.toLowerCase()] ??
        names['en'] ??
        (names.isNotEmpty ? names.values.first : 'Unnamed Subject');
  }

  String getDescription(String langCode) {
    return descriptions[langCode.toLowerCase()] ??
        descriptions['en'] ??
        (descriptions.isNotEmpty ? descriptions.values.first : '');
  }

  // Legacy support for code that expects a single string name
  String get name => getName('en');

  int getCardCountForLanguage(String langCode) {
    if (rawCards == null) return cardCount;
    final lang = langCode.toLowerCase();
    return rawCards!.where((c) {
      final prompts = c['prompts'] as Map<String, dynamic>?;
      final answers = c['answers'] as Map<String, dynamic>?;
      return (prompts != null && prompts.containsKey(lang)) ||
          (answers != null && answers.containsKey(lang));
    }).length;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'names': names,
      'pillar_id': pillarId,
      'descriptions': descriptions,
      'owner_id': ownerId,
      'is_public': isPublic,
      'age_group': ageGroup,
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? allCards =
        json['cards'] is List ? json['cards'] : null;
    final List<dynamic>? activeCards =
        allCards?.where((c) => c['is_deleted'] != true).toList();

    final Map<String, dynamic>? profile = json['profiles'];

    // Handle name/description which might be String (legacy) or Map (new)
    Map<String, String> parsedNames = {};
    if (json['names'] is Map) {
      parsedNames = Map<String, String>.from(json['names']);
    } else if (json['name'] is Map) {
      parsedNames = Map<String, String>.from(json['name']);
    } else if (json['name'] is String) {
      parsedNames = {'en': json['name']};
    }

    Map<String, String> parsedDescriptions = {};
    if (json['descriptions'] is Map) {
      parsedDescriptions = Map<String, String>.from(json['descriptions']);
    } else if (json['description'] is Map) {
      parsedDescriptions = Map<String, String>.from(json['description']);
    } else if (json['description'] is String) {
      parsedDescriptions = {'en': json['description']};
    }

    return SubjectModel(
      id: json['id'],
      names: parsedNames,
      pillarId: json['pillar_id'] ?? 1,
      descriptions: parsedDescriptions,
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
      ageGroup: json['age_group'] ?? 'advanced',
    );
  }
}
