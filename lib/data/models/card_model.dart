import 'subject_model.dart';

class LocalizedCardData {
  final String? prompt;
  final String? answer;
  final String? audioUrl;
  final String? videoUrl;
  final List<String>? imageUrls;
  final Map<String, dynamic> rawData;

  LocalizedCardData({
    this.prompt,
    this.answer,
    this.audioUrl,
    this.videoUrl,
    this.imageUrls,
    this.rawData = const {},
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
      rawData: json,
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

  String getPrompt(String lang) {
    final prompt = _getInherited(lang, (d) => d.prompt) ?? '';
    return capitalizeFirst(prompt);
  }

  String getAnswer(String lang) => _getInherited(lang, (d) => d.answer) ?? '';

  static String capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  List<String> getAnswerList(String lang) {
    final ans = getAnswer(lang);
    if (ans.isEmpty) return [];
    return ans.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  bool isCorrectAnswer(String lang, String input) {
    final answers = getAnswerList(lang);
    if (answers.isEmpty) return false;
    final normalizedInput = input.trim().toLowerCase();
    return answers.any((a) => a.toLowerCase() == normalizedInput);
  }

  String getNumericalChar(String lang) {
    final int val = numericalAnswer;
    
    // Map for special numeral systems
    const Map<int, Map<String, String>> specialNums = {
      0: {'ar': '٠', 'hi': '०', 'zh': '零', 'ja': '零', 'ko': '영'},
      1: {'ar': '١', 'hi': '१', 'zh': '一', 'ja': '一', 'ko': '일'},
      2: {'ar': '٢', 'hi': '२', 'zh': '二', 'ja': '二', 'ko': '이'},
      3: {'ar': '٣', 'hi': '३', 'zh': '三', 'ja': '三', 'ko': '삼'},
      4: {'ar': '٤', 'hi': '४', 'zh': '四', 'ja': '四', 'ko': '사'},
      5: {'ar': '٥', 'hi': '५', 'zh': '五', 'ja': '五', 'ko': '오'},
      6: {'ar': '٦', 'hi': '६', 'zh': '六', 'ja': '六', 'ko': '육'},
      7: {'ar': '٧', 'hi': '७', 'zh': '七', 'ja': '七', 'ko': '칠'},
      8: {'ar': '٨', 'hi': '८', 'zh': '八', 'ja': '八', 'ko': '팔'},
      9: {'ar': '٩', 'hi': '९', 'zh': '九', 'ja': '九', 'ko': '구'},
      10: {'ar': '١٠', 'hi': '१०', 'zh': '十', 'ja': '十', 'ko': '십'},
      11: {'ar': '١١', 'hi': '११', 'zh': '十一', 'ja': '十一', 'ko': '십일'},
      12: {'ar': '١٢', 'hi': '१२', 'zh': '十二', 'ja': '十二', 'ko': '십이'},
      13: {'ar': '١٣', 'hi': '१३', 'zh': '十三', 'ja': '十三', 'ko': '십삼'},
      14: {'ar': '١٤', 'hi': '१٤', 'zh': '十四', 'ja': '十四', 'ko': '십사'},
      15: {'ar': '١٥', 'hi': '१५', 'zh': '十五', 'ja': '十五', 'ko': '십오'},
      16: {'ar': '١٦', 'hi': '१६', 'zh': '十六', 'ja': '十六', 'ko': '십육'},
      17: {'ar': '١٧', 'hi': '१७', 'zh': '十七', 'ja': '十七', 'ko': '십칠'},
      18: {'ar': '١٨', 'hi': '१८', 'zh': '十八', 'ja': '十八', 'ko': '십팔'},
      19: {'ar': '١٩', 'hi': '१९', 'zh': '十九', 'ja': '十九', 'ko': '십구'},
      20: {'ar': '٢٠', 'hi': '२०', 'zh': '二十', 'ja': '二十', 'ko': '이십'},
    };

    if (specialNums.containsKey(val)) {
      return specialNums[val]![lang] ?? val.toString();
    }
    return val.toString();
  }

  int get numericalAnswer {
    // Try global first as it's most likely to be a standard digit
    String? ans = localizedData['global']?.answer;
    ans ??= localizedData['en']?.answer;
    ans ??= getAnswer('en');
    return int.tryParse(ans) ?? 0;
  }

  List<int>? get additionParts {
    final data = localizedData['global'] ?? localizedData['en'] ?? localizedData.values.firstOrNull;
    if (data == null) return null;
    
    final parts = data.rawData['parts'];
    if (parts is List) {
      return parts.map((e) => int.tryParse(e.toString()) ?? 0).toList();
    }
    return null;
  }

  List<int>? get multiplicationParts {
    final data = localizedData['global'] ?? localizedData['en'] ?? localizedData.values.firstOrNull;
    if (data == null) return null;
    
    final parts = data.rawData['parts'];
    if (parts is List) {
      return parts.map((e) => int.tryParse(e.toString()) ?? 0).toList();
    }
    return null;
  }

  List<int>? get divisionParts {
    final data = localizedData['global'] ?? localizedData['en'] ?? localizedData.values.firstOrNull;
    if (data == null) return null;
    
    final parts = data.rawData['parts'];
    if (parts is List) {
      return parts.map((e) => int.tryParse(e.toString()) ?? 0).toList();
    }
    return null;
  }

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

class SubjectCard {
  final CardModel card;
  final SubjectModel subject;

  SubjectCard({required this.card, required this.subject});
}
