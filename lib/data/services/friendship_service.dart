import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:aliolo/core/utils/logger.dart';

class FriendshipService {
  static final FriendshipService _instance = FriendshipService._internal();
  factory FriendshipService() => _instance;
  FriendshipService._internal();

  final _cfClient = getIt<CloudflareHttpClient>();
  AuthService get _authService => getIt<AuthService>();

  Future<String> sendFriendRequest(String email) async {
    try {
      final response = await _cfClient.client.post('/api/friendships/request', data: {
        'email': email,
      });
      if (response.statusCode == 200) return 'success';
      return response.data['error'] ?? 'Request failed';
    } catch (e) {
      return 'user_not_found';
    }
  }

  Future<String> sendFriendRequestById(String targetId) async {
    try {
      final response = await _cfClient.client.post('/api/friendships/request', data: {
        'target_id': targetId,
      });
      if (response.statusCode == 200) return 'success';
      return response.data['error'] ?? 'Request failed';
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> acceptFriendRequest(int friendshipId) async {
    try {
      await _cfClient.client.post('/api/friendships/accept/$friendshipId');
    } catch (e) {
      AppLogger.log('Error accepting friend request: $e');
    }
  }

  Future<void> cancelFriendship(int friendshipId) async {
    try {
      await _cfClient.client.delete('/api/friendships/$friendshipId');
    } catch (e) {
      AppLogger.log('Error canceling friendship: $e');
    }
  }

  Future<bool> hasPendingRequests() async {
    try {
      final res = await getFriendships();
      final user = _authService.currentUser;
      if (user == null) return false;
      
      return res.any((f) => f['status'] == 'pending' && f['receiver_id'] == user.serverId);
    } catch (e) {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getFriendships() async {
    try {
      final response = await _cfClient.client.get('/api/friendships');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        // Transform to match legacy format if needed, but index.ts joins already
        return data.map((f) => {
          ...f as Map<String, dynamic>,
          'sender': {'username': f['sender_username'], 'avatar_url': f['sender_avatar']},
          'receiver': {'username': f['receiver_username'], 'avatar_url': f['receiver_avatar']},
        }).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching friendships: $e');
    }
    return [];
  }

  Future<List<UserModel>> getFriendsLeaderboard({
    int page = 0,
    int pageSize = 20,
  }) async {
    try {
      final response = await _cfClient.client.get('/api/friendships/leaderboard');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((p) => UserModel.fromJson(p)).toList();
      }
    } catch (e) {
      AppLogger.log('Error fetching friends leaderboard: $e');
    }
    return [];
  }
}
