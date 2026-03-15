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

      // 2. Calculate XP (New logic: fixed values, no card level)
      int xpGain = 1; // Incorrect
      if (quality == 5) {
        xpGain = 9; // Perfect
      } else if (quality == 3)
        xpGain = 6; // Correct
      else if (quality == 2)
        xpGain = 3; // Hesitant

      int totalXp = user.totalXp + xpGain;

      // 3. Update Streak & Daily Goal
      double dailyCompletions = user.dailyCompletions;
      int currentStreak = user.currentStreak;
      int maxStreak = user.maxStreak;

      // Only count correct/hesitant answers toward daily goal
      if (quality >= 2) {
        if (user.lastActiveDate == null) {
          dailyCompletions = 1.0;
          if (dailyCompletions >= user.dailyGoalCount) {
            currentStreak = 1;
            totalXp += user.dailyGoalCount; // Streak Bonus
          }
        } else {
          final lastLocal = user.lastActiveDate!.toLocal();
          final lastActiveDay = DateTime(
            lastLocal.year,
            lastLocal.month,
            lastLocal.day,
          );
          final dayDifference = today.difference(lastActiveDay).inDays;

          if (dayDifference == 0) {
            final wasGoalReachedBefore =
                dailyCompletions >= user.dailyGoalCount;
            dailyCompletions += 1.0;
            final isGoalReachedNow = dailyCompletions >= user.dailyGoalCount;

            if (!wasGoalReachedBefore && isGoalReachedNow) {
              currentStreak++;
              totalXp += user.dailyGoalCount; // Streak Bonus
            }
          } else {
            // New day
            if (dayDifference > 1) {
              currentStreak = 0; // Broke streak
            }
            dailyCompletions = 1.0;
            if (dailyCompletions >= user.dailyGoalCount) {
              currentStreak++;
              totalXp += user.dailyGoalCount; // Streak Bonus
            }
          }
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
      int totalXp = user.totalXp + 2;

      // 2. Daily Goal Logic
      double dailyCompletions = user.dailyCompletions;
      int currentStreak = user.currentStreak;
      int maxStreak = user.maxStreak;

      if (user.lastActiveDate == null) {
        dailyCompletions = 0.25;
        if (dailyCompletions >= user.dailyGoalCount) {
          currentStreak = 1;
          totalXp += user.dailyGoalCount;
        }
      } else {
        final lastLocal = user.lastActiveDate!.toLocal();
        final lastActiveDay = DateTime(
          lastLocal.year,
          lastLocal.month,
          lastLocal.day,
        );
        final dayDifference = today.difference(lastActiveDay).inDays;

        if (dayDifference == 0) {
          final wasGoalReachedBefore = dailyCompletions >= user.dailyGoalCount;
          dailyCompletions += 0.25;
          final isGoalReachedNow = dailyCompletions >= user.dailyGoalCount;
          if (!wasGoalReachedBefore && isGoalReachedNow) {
            currentStreak++;
            totalXp += user.dailyGoalCount;
          }
        } else {
          if (dayDifference > 1) currentStreak = 0;
          dailyCompletions = 0.25;
          if (dailyCompletions >= user.dailyGoalCount) {
            currentStreak++;
            totalXp += user.dailyGoalCount;
          }
        }
      }
      if (currentStreak > maxStreak) maxStreak = currentStreak;

      user.totalXp = totalXp;
      user.dailyCompletions = dailyCompletions;
      user.currentStreak = currentStreak;
      user.maxStreak = maxStreak;
      user.lastActiveDate = now;

      await _authService.updateUser(user);
    } catch (e) {
      print('Learn Progress Error: $e');
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
