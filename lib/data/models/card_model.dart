import 'dart:convert';
import 'subject_model.dart';
import 'package:aliolo/core/network/media_url_resolver.dart';

class CardModel {
  final String id;
  final String subjectId;
  final int level;
  final String renderer;
  final String ownerId;
  final bool isPublic;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Base text fields
  final String answer;
  final String prompt;

  /// Base media fields (URLs)
  final List<String> imagesBase;
  final String audio;
  final String video;

  /// Localized maps
  final Map<String, String> answers;
  final Map<String, String> prompts;
  final Map<String, List<String>> imagesLocal;
  final Map<String, String> audios;
  final Map<String, String> videos;

  String? mathQuestion;
  List<String>? mathOptions;

  CardModel({
    required this.id,
    required this.subjectId,
    this.level = 1,
    this.renderer = 'generic',
    required this.ownerId,
    required this.isPublic,
    required this.createdAt,
    required this.updatedAt,
    required this.answer,
    this.answers = const {},
    required this.prompt,
    this.prompts = const {},
    this.imagesBase = const [],
    this.imagesLocal = const {},
    this.audio = '',
    this.audios = const {},
    this.video = '',
    this.videos = const {},
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    Map<String, String> answersMap = {};
    final rawAnswers = json['answers'];
    if (rawAnswers is Map)
      answersMap = Map<String, String>.from(rawAnswers);
    else if (rawAnswers is String && rawAnswers.isNotEmpty) {
      try {
        answersMap = Map<String, String>.from(jsonDecode(rawAnswers));
      } catch (_) {}
    }

    Map<String, String> promptsMap = {};
    final rawPrompts = json['prompts'];
    if (rawPrompts is Map)
      promptsMap = Map<String, String>.from(rawPrompts);
    else if (rawPrompts is String && rawPrompts.isNotEmpty) {
      try {
        promptsMap = Map<String, String>.from(jsonDecode(rawPrompts));
      } catch (_) {}
    }

    List<String> imagesBaseList = [];
    final rawImgBase = json['images_base'];
    if (rawImgBase is List)
      imagesBaseList = List<String>.from(rawImgBase);
    else if (rawImgBase is String && rawImgBase.isNotEmpty) {
      try {
        imagesBaseList = List<String>.from(jsonDecode(rawImgBase));
      } catch (_) {}
    }

    Map<String, List<String>> imagesLocalMap = {};
    final rawImgLocal = json['images_local'];
    if (rawImgLocal is Map) {
      rawImgLocal.forEach((k, v) {
        if (v is List) imagesLocalMap[k] = List<String>.from(v);
      });
    } else if (rawImgLocal is String && rawImgLocal.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawImgLocal) as Map;
        decoded.forEach((k, v) {
          if (v is List) imagesLocalMap[k] = List<String>.from(v);
        });
      } catch (_) {}
    }

    Map<String, String> audiosMap = {};
    final rawAudios = json['audios'];
    if (rawAudios is Map)
      audiosMap = Map<String, String>.from(rawAudios);
    else if (rawAudios is String && rawAudios.isNotEmpty) {
      try {
        audiosMap = Map<String, String>.from(jsonDecode(rawAudios));
      } catch (_) {}
    }

    Map<String, String> videosMap = {};
    final rawVideos = json['videos'];
    if (rawVideos is Map)
      videosMap = Map<String, String>.from(rawVideos);
    else if (rawVideos is String && rawVideos.isNotEmpty) {
      try {
        videosMap = Map<String, String>.from(jsonDecode(rawVideos));
      } catch (_) {}
    }

    // Fallback migration logic
    String bAnswer = json['answer'] ?? '';
    String bPrompt = json['prompt'] ?? '';
    String bAudio = json['audio'] ?? '';
    String bVideo = json['video'] ?? '';

    if (bAnswer.isEmpty && json['localized_data'] != null) {
      var locData = json['localized_data'];
      Map<String, dynamic> locMap = {};
      if (locData is Map)
        locMap = Map<String, dynamic>.from(locData);
      else if (locData is String && locData.isNotEmpty) {
        try {
          locMap = Map<String, dynamic>.from(jsonDecode(locData));
        } catch (_) {}
      }
      final global = locMap['global'];
      if (global is Map) {
        bAnswer = global['answer'] ?? '';
        bPrompt = global['prompt'] ?? '';
        bAudio = global['audio_url'] ?? '';
        bVideo = global['video_url'] ?? '';
        if (imagesBaseList.isEmpty && global['image_urls'] is List) {
          imagesBaseList = List<String>.from(global['image_urls']);
        }
      }
      locMap.forEach((k, v) {
        if (k != 'global' && v is Map) {
          if (answersMap[k] == null) answersMap[k] = v['answer'] ?? '';
          if (promptsMap[k] == null) promptsMap[k] = v['prompt'] ?? '';
          if (audiosMap[k] == null) audiosMap[k] = v['audio_url'] ?? '';
          if (videosMap[k] == null) videosMap[k] = v['video_url'] ?? '';
          if (imagesLocalMap[k] == null && v['image_urls'] is List) {
            imagesLocalMap[k] = List<String>.from(v['image_urls']);
          }
        }
      });
    }

    final rawRenderer = (json['renderer'] ?? '').toString().trim();

    return CardModel(
      id: json['id'],
      subjectId: json['subject_id'] ?? '',
      level: json['level'] ?? 1,
      renderer: rawRenderer.isNotEmpty ? rawRenderer : 'generic',
      ownerId: json['owner_id'] ?? '',
      isPublic: json['is_public'] == true || json['is_public'] == 1,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
      answer: bAnswer,
      answers: answersMap,
      prompt: bPrompt,
      prompts: promptsMap,
      imagesBase: imagesBaseList,
      imagesLocal: imagesLocalMap,
      audio: bAudio,
      audios: audiosMap,
      video: bVideo,
      videos: videosMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_id': subjectId,
      'level': level,
      'renderer': renderer,
      'owner_id': ownerId,
      'is_public': isPublic,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'answer': answer,
      'answers': answers,
      'prompt': prompt,
      'prompts': prompts,
      'images_base': imagesBase,
      'images_local': imagesLocal,
      'audio': audio,
      'audios': audios,
      'video': video,
      'videos': videos,
    };
  }

  String getPrompt(String lang) {
    final lc = lang.toLowerCase();
    if (prompts.containsKey(lc) && prompts[lc]!.isNotEmpty) {
      return capitalizeFirst(prompts[lc]!);
    }
    return capitalizeFirst(prompt);
  }

  String getAnswer(String lang) {
    final lc = lang.toLowerCase();
    if (answers.containsKey(lc) && answers[lc]!.isNotEmpty) {
      return answers[lc]!;
    }
    return answer;
  }

  static String capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  List<String> getAnswerList(String lang) {
    final ans = getAnswer(lang);
    if (ans.isEmpty) return [];
    return ans
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  bool isCorrectAnswer(String lang, String input) {
    final answersList = getAnswerList(lang);
    if (answersList.isEmpty) return false;
    final normalizedInput = input.trim().toLowerCase();
    return answersList.any((a) => a.toLowerCase() == normalizedInput);
  }

  String getNumericalChar(String lang) {
    final int val = numericalAnswer;

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
      13: {'ar': '١٣', 'hi': '१十三', 'zh': '十三', 'ja': '十三', 'ko': '십삼'},
      14: {'ar': '١٤', 'hi': '१४', 'zh': '十四', 'ja': '十四', 'ko': '십사'},
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

  String? get hexColor {
    final ans = getAnswer('en');
    final match = RegExp(r'[,(]\s*(#[0-9a-fA-F]{6})\s*[)]?').firstMatch(ans);
    return match?.group(1);
  }

  bool get isColors => renderer == 'colors' || hexColor != null;
  bool get isSpecialRenderer => renderer != 'generic';
  bool get isMathRenderer => renderer == 'math';
  bool get isMath => isMathRenderer;

  int get numericalAnswer {
    String ans = getAnswer('en');
    if (ans.isEmpty) ans = answer;
    return int.tryParse(ans) ?? 0;
  }

  String? getAudioUrl(String lang) {
    final lc = lang.toLowerCase();
    String? url;
    if (audios.containsKey(lc) && audios[lc]!.isNotEmpty) {
      url = audios[lc];
    } else {
      url = audio;
    }
    return MediaUrlResolver.resolve(url == null || url.isEmpty ? null : url);
  }

  String? getVideoUrl(String lang) {
    final lc = lang.toLowerCase();
    String? url;
    if (videos.containsKey(lc) && videos[lc]!.isNotEmpty) {
      url = videos[lc];
    } else {
      url = video;
    }
    return MediaUrlResolver.resolve(url == null || url.isEmpty ? null : url);
  }

  List<int>? get additionParts {
    final ans = getAnswer('en');
    final match = RegExp(r'(\d+)\s*\+\s*(\d+)').firstMatch(ans);
    if (match != null) {
      return [int.parse(match.group(1)!), int.parse(match.group(2)!)];
    }
    return null;
  }

  List<int>? get multiplicationParts {
    final ans = getAnswer('en');
    final match = RegExp(r'(\d+)\s*[×*]\s*(\d+)').firstMatch(ans);
    if (match != null) {
      return [int.parse(match.group(1)!), int.parse(match.group(2)!)];
    }
    return null;
  }

  List<int>? get divisionParts {
    final ans = getAnswer('en');
    final match = RegExp(r'(\d+)\s*[÷/]\s*(\d+)').firstMatch(ans);
    if (match != null) {
      return [int.parse(match.group(1)!), int.parse(match.group(2)!)];
    }
    return null;
  }

  List<String> getImageUrls(String lang) {
    final lc = lang.toLowerCase();
    List<String> rawUrls = [];
    if (imagesLocal.containsKey(lc) && imagesLocal[lc]!.isNotEmpty) {
      rawUrls = imagesLocal[lc]!;
    } else {
      rawUrls = imagesBase;
    }

    final urls = MediaUrlResolver.resolveList(rawUrls);
    final v = updatedAt.millisecondsSinceEpoch;
    return urls.map((url) {
      if (url.startsWith('http')) {
        return url.contains('?') ? '$url&v=$v' : '$url?v=$v';
      }
      return url;
    }).toList();
  }

  String? primaryImageUrl(String lang) {
    final urls = getImageUrls(lang);
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
      renderer = 'generic',
      ownerId = '',
      isPublic = false,
      createdAt = DateTime.now(),
      updatedAt = DateTime.now(),
      answer = '',
      answers = const {},
      prompt = '',
      prompts = const {},
      imagesBase = const [],
      imagesLocal = const {},
      audio = '',
      audios = const {},
      video = '',
      videos = const {};

}

class SubjectCard {
  final CardModel card;
  final SubjectModel subject;

  SubjectCard({required this.card, required this.subject});
}
