import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/core/di/service_locator.dart';

class ProgressService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final AuthService _authService = getIt<AuthService>();

  Future<void> recordProgress({
    required String userServerId,
    required String cardId,
    required String subjectId,
    required int quality, // 0-5
    required int cardLevel,
  }) async {
    final user = _authService.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      // 1. Update card specific progress in DB
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

      // 2. XP Gain
      int xpGain = 1; // Incorrect
      if (quality == 5) {
        xpGain = 9; // Perfect
      } else if (quality == 3) {
        xpGain = 6; // Correct
      } else if (quality == 2) {
        xpGain = 3; // Hesitant
      }

      user.totalXp += xpGain;

      // 3. New Day Detection & Reset
      _handleNewDayReset(user, today);

      // 4. Update Daily Completions & Streak
      // Only count correct/hesitant answers toward daily goal
      if (quality >= 2) {
        final wasGoalReachedBefore = user.dailyCompletions >= user.dailyGoalCount;
        user.dailyCompletions += 1.0;
        final isGoalReachedNow = user.dailyCompletions >= user.dailyGoalCount;

        if (!wasGoalReachedBefore && isGoalReachedNow) {
          user.currentStreak++;
          user.totalXp += user.dailyGoalCount; // Streak Bonus
        }
      }

      if (user.currentStreak > user.maxStreak) {
        user.maxStreak = user.currentStreak;
      }

      await _authService.patchProgress(
        dailyCompletions: user.dailyCompletions,
        totalXp: user.totalXp,
        currentStreak: user.currentStreak,
        maxStreak: user.maxStreak,
        lastActiveDate: now,
      );
      } catch (e) {
      print('Progress Sync Error: $e');
      }
      }

      Future<void> recordLearnProgress({
      required String cardId,
      required String subjectId,
      }) async {
      final user = _authService.currentUser;
      if (user == null || user.serverId == null) return;

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      try {
      // 1. XP Gain for Learn Mode: 2
      user.totalXp += 2;

      // 2. New Day Detection & Reset
      _handleNewDayReset(user, today);

      // 3. Daily Goal Logic
      final wasGoalReachedBefore = user.dailyCompletions >= user.dailyGoalCount;
      user.dailyCompletions += 0.25;
      final isGoalReachedNow = user.dailyCompletions >= user.dailyGoalCount;

      if (!wasGoalReachedBefore && isGoalReachedNow) {
        user.currentStreak++;
        user.totalXp += user.dailyGoalCount; // Streak Bonus
      }

      if (user.currentStreak > user.maxStreak) {
        user.maxStreak = user.currentStreak;
      }

      user.lastActiveDate = now;
      await _authService.patchProgress(
        dailyCompletions: user.dailyCompletions,
        totalXp: user.totalXp,
        currentStreak: user.currentStreak,
        maxStreak: user.maxStreak,
        lastActiveDate: now,
      );
      } catch (e) {
      print('Learn Progress Error: $e');
      }
      }


  /// Consolidates new day reset logic for completions and streaks.
  void _handleNewDayReset(UserModel user, DateTime today) {
    if (user.lastActiveDate == null) return;

    final lastLocal = user.lastActiveDate!.toLocal();
    final lastDay = DateTime(
      lastLocal.year,
      lastLocal.month,
      lastLocal.day,
    );
    final dayDifference = today.difference(lastDay).inDays;

    if (dayDifference > 0) {
      // New day detected: reset completions and sync goal
      user.dailyCompletions = 0.0;
      user.dailyGoalCount = user.nextDailyGoal;
      if (dayDifference > 1) {
        user.currentStreak = 0; // Broke streak (missed at least one full day)
      }
    }
  }

  Future<void> awardSubjectCompletionBonus(int cardCount) async {
    final user = _authService.currentUser;
    if (user == null) return;
    // Bonus equal to number of cards in the session
    user.totalXp += cardCount;
    await _authService.updateUser(user);
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

  Future<int> getMathLevelCount() async => 0;
  Future<List<ProgressRecord>> getMathRecords() async => [];
  Future<Map<String, int>> getSubjectCrowns() async {
    return {}; // Stub for now
  }

  Future<double> getDailyProgress() async {
    return _authService.currentUser?.dailyCompletions ?? 0.0;
  }
}
