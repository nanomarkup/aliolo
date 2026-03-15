import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/auth_service.dart';

class FriendshipService {
  static final FriendshipService _instance = FriendshipService._internal();
  factory FriendshipService() => _instance;
  FriendshipService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;
  final _authService = AuthService();

  Future<String> sendFriendRequest(String email) async {
    final currentUser = _authService.currentUser;
    if (currentUser == null || currentUser.serverId == null) {
      return 'Not logged in';
    }
    if (email.toLowerCase() == currentUser.email.toLowerCase()) {
      return 'Cannot add yourself';
    }

    try {
      // 1. Find user by email
      final targetUserRes =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('email', email.toLowerCase())
              .maybeSingle();

      if (targetUserRes == null) return 'User not found';
      final String targetId = targetUserRes['id'];

      // 2. Check if friendship already exists (any direction)
      final existing =
          await _supabase
              .from('user_friendships')
              .select()
              .or(
                'and(sender_id.eq.${currentUser.serverId},receiver_id.eq.$targetId),and(sender_id.eq.$targetId,receiver_id.eq.${currentUser.serverId})',
              )
              .maybeSingle();

      if (existing != null) {
        if (existing['status'] == 'accepted') return 'You are already friends';
        return 'Request already pending';
      }

      // 3. Send request
      await _supabase.from('user_friendships').insert({
        'sender_id': currentUser.serverId,
        'receiver_id': targetId,
        'status': 'pending',
      });

      return 'success';
    } on PostgrestException catch (e) {
      if (e.message.contains('unique_friendship')) {
        return 'Request already exists';
      }
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  Future<void> acceptFriendRequest(int friendshipId) async {
    await _supabase
        .from('user_friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
  }

  Future<void> cancelFriendship(int friendshipId) async {
    await _supabase.from('user_friendships').delete().eq('id', friendshipId);
  }

  Future<List<Map<String, dynamic>>> getFriendships() async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];

    try {
      final res = await _supabase
          .from('user_friendships')
          .select(
            '*, sender:profiles!sender_id(*), receiver:profiles!receiver_id(*)',
          )
          .or('sender_id.eq.${user.serverId},receiver_id.eq.${user.serverId}');

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error fetching friendships: $e');
      return [];
    }
  }

  Future<List<UserModel>> getFriendsLeaderboard({
    int page = 0,
    int pageSize = 20,
  }) async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];

    try {
      final friendships = await _supabase
          .from('user_friendships')
          .select('sender_id, receiver_id')
          .eq('status', 'accepted')
          .or('sender_id.eq.${user.serverId},receiver_id.eq.${user.serverId}');

      final Set<String> friendIds = {user.serverId!};
      for (var f in friendships) {
        friendIds.add(f['sender_id']);
        friendIds.add(f['receiver_id']);
      }

      final profilesRes = await _supabase
          .from('profiles')
          .select()
          .inFilter('id', friendIds.toList())
          .order('total_xp', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return List<dynamic>.from(
        profilesRes,
      ).map((p) => UserModel.fromJson(p)).toList();
    } catch (e) {
      print('Error fetching friends leaderboard: $e');
      return [];
    }
  }
}
