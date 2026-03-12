import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/auth_service.dart';

class ProgressService {
  static final ProgressService _instance = ProgressService._internal();
  factory ProgressService() => _instance;
  ProgressService._internal();

  final _authService = AuthService();
  SupabaseClient get _supabase => Supabase.instance.client;

  Future<void> recordCorrectAnswer(
    String cardId,
    String subjectId, {
    int quality = 5,
    int cardLevel = 1,
  }) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final userServerId = user.serverId!;

    try {
      final remoteRes =
          await _supabase
              .from('progress')
              .select()
              .eq('user_id', userServerId)
              .eq('card_id', cardId)
              .maybeSingle();
      int currentCorrect = 0;
      if (remoteRes != null) {
        currentCorrect = remoteRes['correct_count'] ?? 0;
      }

      await _supabase.from('progress').upsert({
        'user_id': userServerId,
        'card_id': cardId,
        'subject_id': subjectId,
        'correct_count': (quality >= 3) ? currentCorrect + 1 : currentCorrect,
        'updated_at': now.toIso8601String(),
      }, onConflict: 'user_id, card_id');

      int xpGain = 1;
      if (quality == 5)
        xpGain = 9;
      else if (quality == 3)
        xpGain = 6;
      else if (quality == 2)
        xpGain = 3;

      int totalXp = user.totalXp + xpGain + cardLevel;

      int dailyCompletions = user.dailyCompletions;
      int currentStreak = user.currentStreak;
      int maxStreak = user.maxStreak;

      if (quality >= 3) {
        if (user.lastActiveDate == null) {
          dailyCompletions = 1;
          if (dailyCompletions >= user.dailyGoalCount) currentStreak = 1;
        } else {
          final lastActiveDay = DateTime(
            user.lastActiveDate!.year,
            user.lastActiveDate!.month,
            user.lastActiveDate!.day,
          );
          final dayDifference = today.difference(lastActiveDay).inDays;
          if (dayDifference == 0) {
            dailyCompletions++;
          } else {
            if (dayDifference > 1 || dailyCompletions < user.dailyGoalCount)
              currentStreak = 0;
            dailyCompletions = 1;
          }
          if (dailyCompletions == user.dailyGoalCount) currentStreak++;
        }
        if (currentStreak > maxStreak) maxStreak = currentStreak;
      }

      user.totalXp = totalXp;
      user.dailyCompletions = dailyCompletions;
      user.currentStreak = currentStreak;
      user.maxStreak = maxStreak;
      user.lastActiveDate = now;

      await _authService.updateUser(user);
    } catch (e) {
      print('Progress Sync Error: $e');
    }
  }

  Future<void> hideCard(String cardId, bool hidden) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return;
    try {
      await _supabase.from('progress').upsert({
        'user_id': user.serverId,
        'card_id': cardId,
        'is_hidden': hidden,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id, card_id');
    } catch (_) {}
  }

  Future<List<String>> getHiddenCardIds() async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];
    try {
      final List<dynamic> res = await _supabase
          .from('progress')
          .select('card_id')
          .eq('user_id', user.serverId!)
          .eq('is_hidden', true);
      return res.map((e) => e['card_id'] as String).toList();
    } catch (_) {
      return [];
    }
  }

  Future<double> getSubjectProgress(String subjectId) async {
    return 0.0;
  }

  Future<void> awardSubjectCompletionBonus() async {
    final user = _authService.currentUser;
    if (user == null) return;
    user.totalXp += 50;
    await _authService.updateUser(user);
  }

  Future<int> getMathLevelCount() async => 0;
  Future<List<ProgressRecord>> getMathRecords() async => [];
  Future<Map<String, int>> getSubjectCrowns() async {
    return {}; // Stub for now
  }

  Future<int> getDailyProgress() async {
    return _authService.currentUser?.dailyCompletions ?? 0;
  }
}
