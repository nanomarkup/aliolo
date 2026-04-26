import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/utils/logger.dart';
import 'package:aliolo/data/models/subject_usage_model.dart';

class SubjectUsageService {
  final _cfClient = getIt<CloudflareHttpClient>();

  Future<void> recordSessionStart({
    required Iterable<String> subjectIds,
    required String mode,
  }) async {
    await _recordSessionEvent('start', subjectIds: subjectIds, mode: mode);
  }

  Future<void> recordSessionComplete({
    required Iterable<String> subjectIds,
    required String mode,
  }) async {
    await _recordSessionEvent('complete', subjectIds: subjectIds, mode: mode);
  }

  Future<void> _recordSessionEvent(
    String event, {
    required Iterable<String> subjectIds,
    required String mode,
  }) async {
    final ids =
        subjectIds
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();
    if (ids.isEmpty) return;

    try {
      await _cfClient.client.post(
        '/api/analytics/subject-session/$event',
        data: {'subject_ids': ids, 'mode': mode},
      );
    } catch (e) {
      AppLogger.log('SubjectUsageService: failed to record $event: $e');
    }
  }

  Future<List<SubjectUsageModel>> getSubjectUsage({String period = 'all'}) async {
    try {
      final response = await _cfClient.client.get(
        '/api/admin/subject-usage',
        queryParameters: {'period': period},
      );
      if (response.statusCode == 200 && response.data is List) {
        return (response.data as List)
            .whereType<Map>()
            .map(
              (row) =>
                  SubjectUsageModel.fromJson(Map<String, dynamic>.from(row)),
            )
            .toList();
      }
    } catch (e) {
      AppLogger.log('SubjectUsageService: failed to fetch usage: $e');
      rethrow;
    }
    return [];
  }
}
