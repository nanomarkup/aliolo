import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/utils/logger.dart';
import 'package:aliolo/data/models/onboarding_analytics_model.dart';

class OnboardingAnalyticsService {
  final _cfClient = getIt<CloudflareHttpClient>();

  Future<OnboardingAnalyticsPageModel> getOnboardingAnalytics() async {
    try {
      final response = await _cfClient.client.get(
        '/api/admin/onboarding-analytics',
      );
      if (response.statusCode == 200 && response.data is Map) {
        return OnboardingAnalyticsPageModel.fromJson(
          Map<String, dynamic>.from(response.data as Map),
        );
      }
    } catch (e) {
      AppLogger.log(
        'OnboardingAnalyticsService: failed to fetch analytics: $e',
      );
      rethrow;
    }

    return OnboardingAnalyticsPageModel.empty;
  }
}
