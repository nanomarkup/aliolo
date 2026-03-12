class CardModel {
  final String id; // Renamed from cardId
  final String subjectId; 
  final int level;
  final Map<String, String> prompts; 
  final Map<String, String> answers; 
  final String? videoUrl;
  final String? imageUrl;
  final List<String> imageUrls;
  final String ownerId;
  final bool isPublic;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  String? mathQuestion;
  List<String>? mathOptions;

  CardModel({
    required this.id,
    required this.subjectId,
    this.level = 1,
    required this.prompts,
    required this.answers,
    this.videoUrl,
    this.imageUrl,
    this.imageUrls = const [],
    required this.ownerId,
    required this.isPublic,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'], // Updated from card_id
      subjectId: json['subject_id'] ?? '',
      level: json['level'] ?? 1,
      prompts: Map<String, String>.from(json['prompts'] ?? {}),
      answers: Map<String, String>.from(json['answers'] ?? {}),
      videoUrl: json['video_url'],
      imageUrl: json['image_url'],
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      ownerId: json['owner_id'] ?? '',
      isPublic: json['is_public'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  CardModel.empty() : 
    id = '', subjectId = '', level = 1, 
    prompts = {}, answers = {}, ownerId = '', isPublic = false,
    isDeleted = false, createdAt = DateTime.now(), updatedAt = DateTime.now(),
    videoUrl = null, imageUrl = null, imageUrls = const [];
}
