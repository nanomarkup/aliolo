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
  late bool autoPlayEnabled;
  late int mainPillarId; 

  late int totalXp;
  late int currentStreak;
  late int maxStreak;
  DateTime? lastActiveDate;
  late int dailyGoalCount;
  late int nextDailyGoal;
  late double dailyCompletions;
  late int learnSessionSize;
  late int testSessionSize;
  late int optionsCount;
  late String defaultLanguage;
  late String? avatarPath;
  late bool showOnLeaderboard;

  UserModel({
    required this.username,
    required this.email,
    this.sidebarLeft = false,
    this.themeMode = 'system',
    this.uiLanguage = 'en',
    this.soundEnabled = true,
    this.autoPlayEnabled = false,
    this.mainPillarId = 8,
    this.totalXp = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.lastActiveDate,
    this.dailyGoalCount = 20,
    this.nextDailyGoal = 20,
    this.dailyCompletions = 0.0,
    this.learnSessionSize = 20,
    this.testSessionSize = 10,
    this.optionsCount = 6,
    this.defaultLanguage = 'EN',
    this.avatarPath,
    this.showOnLeaderboard = true,
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
      nextDailyGoal: json['next_daily_goal'] ?? 20,
      dailyCompletions: (json['daily_completions'] ?? 0).toDouble(),
      sidebarLeft: json['sidebar_left'] ?? false,
      soundEnabled: json['sound_enabled'] ?? true,
      autoPlayEnabled: json['auto_play_enabled'] ?? false,
      mainPillarId: json['main_pillar_id'] ?? 8,
      showOnLeaderboard: json['show_on_leaderboard'] ?? true,
      learnSessionSize: json['learn_session_size'] ?? json['session_size'] ?? 20,
      testSessionSize: json['test_session_size'] ?? json['session_size'] ?? 10,
      optionsCount: json['options_count'] ?? 6,
      defaultLanguage: (json['default_language'] ?? 'en').toString().toLowerCase(),
      avatarPath: json['avatar_url'],
      isDeleted: json['is_deleted'] ?? false,
      lastActiveDate: DateTime.tryParse(json['last_active_date'] ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? ''),
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
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
      'next_daily_goal': nextDailyGoal,
      'daily_completions': dailyCompletions,
      'sidebar_left': sidebarLeft,
      'sound_enabled': soundEnabled,
      'auto_play_enabled': autoPlayEnabled,
      'main_pillar_id': mainPillarId,
      'show_on_leaderboard': showOnLeaderboard,
      'learn_session_size': learnSessionSize,
      'test_session_size': testSessionSize,
      'options_count': optionsCount,
      'default_language': defaultLanguage.toLowerCase(),
      'avatar_url': avatarPath,
      'is_deleted': isDeleted,
      'last_active_date': lastActiveDate?.toIso8601String(),
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
      id: json['card_id'] ?? '',
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
