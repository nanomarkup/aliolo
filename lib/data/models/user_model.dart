import 'package:flutter/material.dart';

class UserModel {
  String? serverId;
  late String username;
  late String email;
  late bool sidebarLeft;
  late String themeMode;
  late String uiLanguage;
  late bool soundEnabled;
  late bool showOnLeaderboard;
  late int learnSessionSize;
  late int testSessionSize;
  String? avatarPath;
  late String defaultLanguage;
  DateTime? lastActiveDate;
  late int totalXp;
  late int currentStreak;
  late int maxStreak;
  late int dailyGoalCount;
  late int optionsCount;
  late int nextDailyGoal;
  late double dailyCompletions;
  late bool autoPlayEnabled;
  late bool showDocumentation;
  late int mainPillarId; 
  DateTime? createdAt;
  DateTime? updatedAt;
  bool isPremium;

  UserModel({
    this.serverId,
    required this.username,
    required this.email,
    this.sidebarLeft = false,
    this.themeMode = 'system',
    this.uiLanguage = 'en',
    this.soundEnabled = true,
    this.showOnLeaderboard = true,
    this.learnSessionSize = 10,
    this.testSessionSize = 10,
    this.avatarPath,
    this.defaultLanguage = 'EN',
    this.lastActiveDate,
    this.totalXp = 0,
    this.currentStreak = 0,
    this.maxStreak = 0,
    this.dailyGoalCount = 20,
    this.optionsCount = 6,
    this.nextDailyGoal = 20,
    this.dailyCompletions = 0,
    this.autoPlayEnabled = false,
    this.showDocumentation = true,
    this.mainPillarId = 8,
    this.createdAt,
    this.updatedAt,
    this.isPremium = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      serverId: json['id'],
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      sidebarLeft: json['sidebar_left'] ?? false,
      themeMode: json['theme_mode'] ?? 'system',
      uiLanguage: json['ui_language'] ?? 'en',
      soundEnabled: json['sound_enabled'] ?? true,
      showOnLeaderboard: json['show_on_leaderboard'] ?? true,
      learnSessionSize: json['learn_session_size'] ?? 10,
      testSessionSize: json['test_session_size'] ?? 10,
      avatarPath: json['avatar_url'],
      defaultLanguage: (json['default_language'] ?? 'EN').toString().toUpperCase(),
      lastActiveDate: json['last_active_date'] != null ? DateTime.parse(json['last_active_date']) : null,
      totalXp: json['total_xp'] ?? 0,
      currentStreak: json['current_streak'] ?? 0,
      maxStreak: json['max_streak'] ?? 0,
      dailyGoalCount: json['daily_goal_count'] ?? 20,
      optionsCount: json['options_count'] ?? 6,
      nextDailyGoal: json['next_daily_goal'] ?? 20,
      dailyCompletions: (json['daily_completions'] ?? 0).toDouble(),
      autoPlayEnabled: json['auto_play_enabled'] ?? false,
      showDocumentation: json['show_documentation'] ?? true,
      mainPillarId: json['main_pillar_id'] ?? 8,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at']) : null,
      isPremium: json['is_premium'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': serverId,
      'username': username,
      'email': email,
      'sidebar_left': sidebarLeft,
      'theme_mode': themeMode,
      'ui_language': uiLanguage,
      'sound_enabled': soundEnabled,
      'show_on_leaderboard': showOnLeaderboard,
      'learn_session_size': learnSessionSize,
      'test_session_size': testSessionSize,
      'avatar_url': avatarPath,
      'default_language': defaultLanguage.toLowerCase(),
      'last_active_date': lastActiveDate?.toUtc().toIso8601String(),
      'total_xp': totalXp,
      'current_streak': currentStreak,
      'max_streak': maxStreak,
      'daily_goal_count': dailyGoalCount,
      'options_count': optionsCount,
      'next_daily_goal': nextDailyGoal,
      'daily_completions': dailyCompletions,
      'auto_play_enabled': autoPlayEnabled,
      'show_documentation': showDocumentation,
      'main_pillar_id': mainPillarId,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  Color getThemeColor(BuildContext context) {
    if (themeMode == 'light') return Colors.white;
    if (themeMode == 'dark') return const Color(0xFF1A1C1E);
    return MediaQuery.of(context).platformBrightness == Brightness.dark
        ? const Color(0xFF1A1C1E)
        : Colors.white;
  }

  static String capitalizeFirst(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
