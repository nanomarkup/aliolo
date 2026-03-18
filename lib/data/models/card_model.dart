class LocalizedCardData {
  final String? prompt;
  final String? answer;
  final String? audioUrl;
  final String? videoUrl;
  final List<String>? imageUrls;

  LocalizedCardData({
    this.prompt,
    this.answer,
    this.audioUrl,
    this.videoUrl,
    this.imageUrls,
  });

  factory LocalizedCardData.fromJson(Map<String, dynamic> json) {
    return LocalizedCardData(
      prompt: json['prompt'],
      answer: json['answer'],
      audioUrl: json['audio_url'],
      videoUrl: json['video_url'],
      imageUrls:
          json['image_urls'] != null
              ? List<String>.from(json['image_urls'])
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (prompt != null) 'prompt': prompt,
      if (answer != null) 'answer': answer,
      if (audioUrl != null) 'audio_url': audioUrl,
      if (videoUrl != null) 'video_url': videoUrl,
      if (imageUrls != null) 'image_urls': imageUrls,
    };
  }
}

class CardModel {
  final String id;
  final String subjectId;
  final int level;
  final String testMode;
  final String ownerId;
  final bool isPublic;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Map of language code to its specific data.
  /// Key 'global' is used for fallback assets (image/video).
  final Map<String, LocalizedCardData> localizedData;

  String? mathQuestion;
  List<String>? mathOptions;

  CardModel({
    required this.id,
    required this.subjectId,
    this.level = 1,
    this.testMode = 'image_to_text',
    required this.ownerId,
    required this.isPublic,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
    this.localizedData = const {},
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> locMap = json['localized_data'] ?? {};
    final localized = locMap.map(
      (key, value) => MapEntry(
        key.toLowerCase(),
        LocalizedCardData.fromJson(value as Map<String, dynamic>),
      ),
    );

    return CardModel(
      id: json['id'],
      subjectId: json['subject_id'] ?? '',
      level: json['level'] ?? 1,
      testMode: json['test_mode'] ?? json['kind'] ?? 'image_to_text',
      ownerId: json['owner_id'] ?? '',
      isPublic: json['is_public'] ?? false,
      isDeleted: json['is_deleted'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      localizedData: localized,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'level': level,
      'test_mode': testMode,
      'owner_id': ownerId,
      'is_public': isPublic,
      'is_deleted': isDeleted,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'localized_data': localizedData.map((k, v) => MapEntry(k, v.toJson())),
    };
  }

  /// Helper to get an attribute with smart inheritance
  T? _getInherited<T>(String lang, T? Function(LocalizedCardData) getter) {
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
    return null;
  }

  String getPrompt(String lang) => _getInherited(lang, (d) => d.prompt) ?? '';
  String getAnswer(String lang) => _getInherited(lang, (d) => d.answer) ?? '';
  String? getAudioUrl(String lang) => _getInherited(lang, (d) => d.audioUrl);
  String? getVideoUrl(String lang) => _getInherited(lang, (d) => d.videoUrl);
  List<String> getImageUrls(String lang) =>
      _getInherited(lang, (d) => d.imageUrls) ?? [];

  String? get primaryImageUrl {
    final urls = getImageUrls('global');
    return urls.isNotEmpty ? urls.first : null;
  }

  bool get isAudioOnly {
    final vid = getVideoUrl('global');
    if (vid == null || vid.isEmpty) return false;
    final path = vid.toLowerCase().split('?').first;
    return path.endsWith('.mp3') ||
        path.endsWith('.wav') ||
        path.endsWith('.m4a') ||
        path.endsWith('.aac') ||
        path.endsWith('.ogg');
  }

  CardModel.empty()
    : id = '',
      subjectId = '',
      level = 1,
      testMode = 'image_to_text',
      ownerId = '',
      isPublic = false,
      isDeleted = false,
      createdAt = DateTime.now(),
      updatedAt = DateTime.now(),
      localizedData = const {};
}
