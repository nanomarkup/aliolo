import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aliolo/data/models/friendship_model.dart';
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
    if (currentUser == null || currentUser.serverId == null) return 'Not logged in';
    if (email.toLowerCase() == currentUser.email.toLowerCase()) return 'Cannot add yourself';

    try {
      // 1. Find user by email
      final targetUserRes = await _supabase
          .from('profiles')
          .select('id')
          .eq('email', email.toLowerCase())
          .maybeSingle();

      if (targetUserRes == null) return 'User not found';
      final String targetId = targetUserRes['id'];

      // 2. Send request
      await _supabase.from('user_friendships').insert({
        'sender_id': currentUser.serverId,
        'receiver_id': targetId,
        'status': 'pending',
      });

      return 'success';
    } on PostgrestException catch (e) {
      if (e.message.contains('unique_friendship')) return 'Request already exists';
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
          .select('*, sender:profiles!sender_id(*), receiver:profiles!receiver_id(*)')
          .or('sender_id.eq.${user.serverId},receiver_id.eq.${user.serverId}');

      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      print('Error fetching friendships: $e');
      return [];
    }
  }

  Future<List<UserModel>> getFriendsLeaderboard() async {
    final user = _authService.currentUser;
    if (user == null || user.serverId == null) return [];

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
        .order('total_xp', ascending: false);

    return List<dynamic>.from(profilesRes).map((p) => UserModel(
      username: p['username'] ?? 'Learner',
      email: p['email'] ?? '',
      serverId: p['id'],
      totalXp: p['total_xp'] ?? 0,
      currentStreak: p['current_streak'] ?? 0,
      maxStreak: p['max_streak'] ?? 0,
    )).toList();
  }
}
