class CardModel {
  final String id; // Renamed from cardId
  final String subjectId;
  final int level;
  final Map<String, String> prompts;
  final Map<String, String> answers;
  final String? videoUrl;
  final String? imageUrl;
  final List<String> imageUrls;
  final String kind;
  final Map<String, String> audioUrls;
  final String ownerId;
  final bool isPublic;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isAudio {
    if (videoUrl == null || videoUrl!.isEmpty) return false;
    final path = videoUrl!.toLowerCase().split('?').first;
    return path.endsWith('.mp3') ||
        path.endsWith('.wav') ||
        path.endsWith('.m4a') ||
        path.endsWith('.aac') ||
        path.endsWith('.ogg');
  }

  String? get effectiveVideoUrl => videoUrl;

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
    this.kind = 'image_to_text',
    this.audioUrls = const {},
    required this.ownerId,
    required this.isPublic,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'],
      subjectId: json['subject_id'] ?? '',
      level: json['level'] ?? 1,
      prompts: Map<String, String>.from(json['prompts'] ?? {}),
      answers: Map<String, String>.from(json['answers'] ?? {}),
      videoUrl: json['video_url'],
      imageUrl: json['image_url'],
      imageUrls: List<String>.from(json['image_urls'] ?? []),
      kind: json['kind'] ?? 'image_to_text',
      audioUrls: Map<String, String>.from(json['audio_urls'] ?? {}),
      ownerId: json['owner_id'] ?? '',
      isPublic: json['is_public'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  CardModel.empty()
    : id = '',
      subjectId = '',
      level = 1,
      prompts = {},
      answers = {},
      ownerId = '',
      isPublic = false,
      isDeleted = false,
      createdAt = DateTime.now(),
      updatedAt = DateTime.now(),
      videoUrl = null,
      imageUrl = null,
      kind = 'image_to_text',
      audioUrls = const {},
      imageUrls = const [];
}
