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
}
