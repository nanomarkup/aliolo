class UserModel {
  int id = 0; 
  late String username;
  late String email;
  String? serverId; 
  DateTime? createdAt;
  DateTime? updatedAt;
  bool isDeleted = false;

  late bool sidebarLeft;
  late String themeMode; 
  late String uiLanguage;
  late bool soundEnabled;

  late int totalXp;
  late int currentStreak;
  late int maxStreak;
  DateTime? lastActiveDate;
  late int dailyGoalCount;
  late int dailyCompletions;
  late int sessionSize;
  late int optionsCount;
  late String defaultLanguage;
  late String? avatarPath;
  late bool showOnLeaderboard;
  late int shortcutPrevKey;
  late int shortcutNextKey;

  UserModel({
    required this.username,
    required this.email,
    this.sidebarLeft = false,
    this.themeMode = 'system',
    this.uiLanguage = 'en',
    this.soundEnabled = true,
    this.totalXp = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.lastActiveDate,
    this.dailyGoalCount = 20,
    this.dailyCompletions = 0,
    this.sessionSize = 10,
    this.optionsCount = 6,
    this.defaultLanguage = 'EN',
    this.avatarPath,
    this.showOnLeaderboard = true,
    this.shortcutPrevKey = 1067,
    this.shortcutNextKey = 1066,
    this.serverId,
    this.createdAt,
    this.updatedAt,
    this.isDeleted = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      serverId: json['id'],
      totalXp: json['total_xp'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      maxStreak: json['max_streak'] ?? 0,
      themeMode: json['theme_mode'] ?? 'system',
      uiLanguage: json['ui_language'] ?? 'en',
      dailyGoalCount: json['daily_goal_count'] ?? 20,
      sidebarLeft: json['sidebar_left'] ?? false,
      soundEnabled: json['sound_enabled'] ?? true,
      showOnLeaderboard: json['show_on_leaderboard'] ?? true,
      sessionSize: json['session_size'] ?? 10,
      optionsCount: json['options_count'] ?? 6,
      defaultLanguage: (json['default_language'] ?? 'en').toString().toLowerCase(),
      shortcutPrevKey: (json['shortcut_prev_key'] as num?)?.toInt() ?? 1067,
      shortcutNextKey: (json['shortcut_next_key'] as num?)?.toInt() ?? 1066,
      avatarPath: json['avatar_url'],
      updatedAt: DateTime.tryParse(json['updated_at'] ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': serverId,
      'username': username,
      'email': email,
      'total_xp': totalXp,
      'current_streak': currentStreak,
      'max_streak': maxStreak,
      'theme_mode': themeMode,
      'ui_language': uiLanguage,
      'daily_goal_count': dailyGoalCount,
      'sidebar_left': sidebarLeft,
      'sound_enabled': soundEnabled,
      'show_on_leaderboard': showOnLeaderboard,
      'session_size': sessionSize,
      'options_count': optionsCount,
      'default_language': defaultLanguage.toLowerCase(),
      'shortcut_prev_key': shortcutPrevKey,
      'shortcut_next_key': shortcutNextKey,
      'avatar_url': avatarPath,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserModel.empty();
}

class ProgressRecord {
  final String userServerId;
  final String id; // This is the card's ID
  int correctCount;
  bool isHidden;
  double easeFactor;
  int interval;
  int repetitionCount;
  DateTime nextReview;
  DateTime createdAt;
  DateTime? updatedAt;

  ProgressRecord({
    required this.userServerId,
    required this.id,
    this.correctCount = 0,
    this.isHidden = false,
    this.easeFactor = 2.5,
    this.interval = 0,
    this.repetitionCount = 0,
    required this.nextReview,
    required this.createdAt,
    this.updatedAt,
  });

  factory ProgressRecord.fromJson(Map<String, dynamic> json) {
    return ProgressRecord(
      userServerId: json['user_id'] ?? '',
      id: json['card_id'] ?? '', // Map card_id from DB to id in model
      correctCount: json['correct_count'] ?? 0,
      isHidden: json['is_hidden'] ?? false,
      easeFactor: (json['ease_factor'] ?? 2.5).toDouble(),
      interval: json['interval'] ?? 0,
      repetitionCount: json['repetition_count'] ?? 0,
      nextReview: DateTime.tryParse(json['next_review'] ?? '') ?? DateTime.now(),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }
}
