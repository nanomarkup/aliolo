import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/utils/logger.dart';

class ReviewSessionCardSelection {
  final List<String> cardIds;
  final bool succeeded;
  final String? errorMessage;

  const ReviewSessionCardSelection._({
    required this.cardIds,
    required this.succeeded,
    this.errorMessage,
  });

  const ReviewSessionCardSelection.success(List<String> cardIds)
    : this._(cardIds: cardIds, succeeded: true);

  const ReviewSessionCardSelection.failure(String errorMessage)
    : this._(cardIds: const [], succeeded: false, errorMessage: errorMessage);
}

class ProgressService {
  final _cfClient = getIt<CloudflareHttpClient>();
  final AuthService _authService = getIt<AuthService>();

  Future<void> recordProgress({
    required String userServerId,
    required String cardId,
    required String subjectId,
    required int quality, // 0-5
    required int cardLevel,
  }) async {
    await recordReview(cardId: cardId, subjectId: subjectId, quality: quality);
  }

  Future<List<String>> getReviewSessionCardIds({
    required List<String> cardIds,
    required int limit,
  }) async {
    final selection = await getReviewSessionCardSelection(
      cardIds: cardIds,
      limit: limit,
    );
    return selection.cardIds;
  }

  Future<ReviewSessionCardSelection> getReviewSessionCardSelection({
    required List<String> cardIds,
    required int limit,
  }) async {
    if (cardIds.isEmpty || limit <= 0) {
      return const ReviewSessionCardSelection.success([]);
    }

    try {
      final response = await _cfClient.client.post(
        '/api/progress/review-session',
        data: {'card_ids': cardIds, 'limit': limit},
      );
      if (response.statusCode == 200 && response.data is Map) {
        final data = Map<String, dynamic>.from(response.data);
        final selected = data['card_ids'];
        if (selected is List) {
          return ReviewSessionCardSelection.success(
            selected.map((id) => '$id').toList(),
          );
        }
      }
      final message =
          'Unexpected SM-2 review session response: ${response.statusCode}';
      AppLogger.log(message);
      return ReviewSessionCardSelection.failure(message);
    } catch (e) {
      final message = 'Error getting SM-2 review session cards: $e';
      AppLogger.log(message);
      return ReviewSessionCardSelection.failure(message);
    }
  }

  Future<void> recordReview({
    required String cardId,
    required String subjectId,
    required int quality,
  }) async {
    final user = _authService.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      await _cfClient.client.post(
        '/api/progress/review',
        data: {'card_id': cardId, 'subject_id': subjectId, 'quality': quality},
      );

      int xpGain = 1; // Incorrect
      if (quality == 5) {
        xpGain = 9; // Perfect
      } else if (quality == 3) {
        xpGain = 6; // Correct
      } else if (quality == 2) {
        xpGain = 3; // Hesitant
      }

      user.totalXp += xpGain;

      _handleNewDayReset(user, today);

      if (quality >= 2) {
        final wasGoalReachedBefore =
            user.dailyCompletions >= user.dailyGoalCount;
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
      AppLogger.log('Progress Sync Error: $e');
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
      user.totalXp += 2;
      _handleNewDayReset(user, today);

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
      AppLogger.log('Learn Progress Error: $e');
    }
  }

  void _handleNewDayReset(UserModel user, DateTime today) {
    if (user.lastActiveDate == null) return;

    final lastLocal = user.lastActiveDate!.toLocal();
    final lastDay = DateTime(lastLocal.year, lastLocal.month, lastLocal.day);
    final dayDifference = today.difference(lastDay).inDays;

    if (dayDifference > 0) {
      user.dailyCompletions = 0.0;
      user.dailyGoalCount = user.nextDailyGoal;
      if (dayDifference > 1) {
        user.currentStreak = 0;
      }
    }
  }

  Future<void> awardSubjectCompletionBonus(int cardCount) async {
    final user = _authService.currentUser;
    if (user == null) return;
    user.totalXp += cardCount;
    await _authService.updateUser(user);
  }

  Future<void> hideCard(String cardId, bool hidden) async {
    try {
      await _cfClient.client.post(
        '/api/progress',
        data: {'card_id': cardId, 'is_hidden': hidden},
      );
    } catch (e) {
      AppLogger.log('Error hiding card: $e');
    }
  }

  Future<List<String>> getHiddenCardIds() async {
    try {
      final response = await _cfClient.client.get('/api/progress/hidden');
      if (response.statusCode == 200) {
        return List<String>.from(response.data);
      }
    } catch (e) {
      AppLogger.log('Error getting hidden cards: $e');
    }
    return [];
  }

  Future<double> getSubjectProgress(String subjectId) async => 0.0;
  Future<int> getMathLevelCount() async => 0;
  Future<Map<String, int>> getSubjectCrowns() async => {};
  Future<double> getDailyProgress() async =>
      _authService.currentUser?.dailyCompletions ?? 0.0;
}
