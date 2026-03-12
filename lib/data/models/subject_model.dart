class SubjectModel {
  final String id;
  final String name;
  final int pillarId;
  final String? description;
  final String ownerId;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int cardCount;
  final List<Map<String, dynamic>>? rawCards;
  final String? ownerName;
  
  bool isOnDashboard;

  SubjectModel({
    required this.id,
    required this.name,
    required this.pillarId,
    this.description,
    required this.ownerId,
    this.ownerName,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    this.cardCount = 0,
    this.rawCards,
    this.isOnDashboard = false,
  });

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
      'name': name,
      'pillar_id': pillarId,
      'description': description,
      'owner_id': ownerId,
      'is_public': isPublic,
      'updated_at': updatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory SubjectModel.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? allCards = json['cards'] is List ? json['cards'] : null;
    // Filter out deleted cards
    final List<dynamic>? activeCards = allCards?.where((c) => c['is_deleted'] != true).toList();
    
    final Map<String, dynamic>? profile = json['profiles'];
    return SubjectModel(
      id: json['id'],
      name: json['name'],
      pillarId: json['pillar_id'] ?? 1,
      description: json['description'],
      ownerId: json['owner_id'] ?? '',
      ownerName: profile != null ? profile['username'] : null,
      isPublic: json['is_public'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      cardCount: activeCards != null ? activeCards.length : (json['card_count'] ?? 0),
      rawCards: activeCards != null ? List<Map<String, dynamic>>.from(activeCards) : null,
    );
  }
}
