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
  final String displayText;

  /// Base media fields (URLs)
  final List<String> imagesBase;
  final String audio;
  final String video;

  /// Localized maps
  final Map<String, String> answers;
  final Map<String, String> prompts;
  final Map<String, String> displayTexts;
  final Map<String, List<String>> imagesLocal;
  final Map<String, String> audios;
  final Map<String, String> videos;

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
    this.displayText = '',
    this.displayTexts = const {},
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

    Map<String, String> displayTextsMap = {};
    final rawDisplayTexts = json['display_texts'];
    if (rawDisplayTexts is Map) {
      displayTextsMap = Map<String, String>.from(rawDisplayTexts);
    } else if (rawDisplayTexts is String && rawDisplayTexts.isNotEmpty) {
      try {
        displayTextsMap = Map<String, String>.from(jsonDecode(rawDisplayTexts));
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
    String bDisplayText = json['display_text'] ?? '';
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
        bDisplayText = global['display_text'] ?? global['text'] ?? '';
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
          if (displayTextsMap[k] == null) {
            displayTextsMap[k] = v['display_text'] ?? v['text'] ?? '';
          }
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
      displayText: bDisplayText,
      displayTexts: displayTextsMap,
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
      'display_text': displayText,
      'display_texts': displayTexts,
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

  String getDisplayText(String lang) {
    final lc = lang.toLowerCase();
    if (displayTexts.containsKey(lc) && displayTexts[lc]!.isNotEmpty) {
      return displayTexts[lc]!;
    }
    return displayText;
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

  String? get hexColor {
    final ans = getAnswer('en');
    final match = RegExp(r'[,(]\s*(#[0-9a-fA-F]{6})\s*[)]?').firstMatch(ans);
    return match?.group(1);
  }

  bool get isColors => renderer == 'colors' || hexColor != null;
  bool get isSpecialRenderer => renderer != 'generic';
  bool get isCountingRenderer => renderer == 'counting';
  bool get isAdditionEmojiRenderer => renderer == 'addition_emoji';
  bool get isAdditionNumberRenderer => renderer == 'addition_number';
  bool get isSubtractionEmojiRenderer => renderer == 'subtraction_emoji';
  bool get isSubtractionNumberRenderer => renderer == 'subtraction_number';

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
      displayText = '',
      displayTexts = const {},
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
