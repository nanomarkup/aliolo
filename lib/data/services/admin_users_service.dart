import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/utils/logger.dart';
import 'package:aliolo/data/models/admin_user_model.dart';

class AdminUsersService {
  final _cfClient = getIt<CloudflareHttpClient>();

  Future<List<AdminUserModel>> getAllUsers() async {
    try {
      final response = await _cfClient.client.get('/api/admin/users');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data
              .whereType<Map>()
              .map((row) => AdminUserModel.fromJson(Map<String, dynamic>.from(row)))
              .toList();
        }
      }
    } catch (e) {
      AppLogger.log('AdminUsersService: failed to fetch users: $e');
      rethrow;
    }
    return [];
  }

  Future<void> updateSubscription({
    required String userId,
    required String status,
    DateTime? expiryDate,
  }) async {
    try {
      final response = await _cfClient.client.patch(
        '/api/admin/users/$userId/subscription',
        data: {
          'status': status,
          'expiry_date': expiryDate?.toUtc().toIso8601String(),
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update subscription');
      }
    } catch (e) {
      AppLogger.log('AdminUsersService: failed to update subscription: $e');
      rethrow;
    }
  }

  Future<void> updateCardLimit({
    required String userId,
    required int limit,
  }) async {
    try {
      final response = await _cfClient.client.patch(
        '/api/admin/users/$userId/card-limit',
        data: {
          'card_limit': limit,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update card limit');
      }
    } catch (e) {
      AppLogger.log('AdminUsersService: failed to update card limit: $e');
      rethrow;
    }
  }
}
