import 'package:flutter_test/flutter_test.dart';
import 'package:aliolo/data/models/admin_user_model.dart';

void main() {
  Map<String, dynamic> buildUser({
    required String id,
    required String email,
    String username = '',
    bool isPremium = false,
    Map<String, dynamic>? subscription,
  }) {
    return {
      'id': id,
      'username': username,
      'email': email,
      'total_xp': 10,
      'current_streak': 2,
      'max_streak': 5,
      'theme_mode': 'system',
      'ui_language': 'en',
      'default_language': 'en',
      'daily_goal_count': 20,
      'next_daily_goal': 20,
      'daily_completions': 0,
      'sidebar_left': 0,
      'sound_enabled': 1,
      'auto_play_enabled': 0,
      'show_on_leaderboard': 1,
      'show_documentation': 1,
      'learn_session_size': 10,
      'test_session_size': 10,
      'learn_autoplay_delay_seconds': 3,
      'options_count': 6,
      'main_pillar_id': 8,
      'is_premium': isPremium ? 1 : 0,
      'created_at': '2026-04-13T12:00:00Z',
      'updated_at': '2026-04-13T12:00:00Z',
      if (subscription != null) 'subscription': subscription,
    };
  }

  test('matches premium, fake, and free filters', () {
    final premium = AdminUserModel.fromJson(buildUser(
      id: 'user-1',
      email: 'premium@example.com',
      username: 'Premium',
      subscription: {
        'id': 'sub-1',
        'user_id': 'user-1',
        'status': 'active',
        'provider': 'aliolo',
        'expiry_date': '2026-12-31T00:00:00Z',
      },
    ));

    final fake = AdminUserModel.fromJson(buildUser(
      id: 'user-2',
      email: 'fake_user@example.com',
      username: 'Fake User',
    ));

    final free = AdminUserModel.fromJson(buildUser(
      id: 'user-3',
      email: 'free@example.com',
      username: 'Free User',
    ));

    expect(premium.isPremium, isTrue);
    expect(premium.matchesFilter(AdminUsersFilter.premium), isTrue);
    expect(premium.matchesFilter(AdminUsersFilter.free), isFalse);

    expect(fake.isFake, isTrue);
    expect(fake.matchesFilter(AdminUsersFilter.fake), isTrue);
    expect(fake.matchesFilter(AdminUsersFilter.free), isFalse);

    expect(free.isFree, isTrue);
    expect(free.matchesFilter(AdminUsersFilter.free), isTrue);
  });

  test('uses profile premium flag or active subscription', () {
    final premiumByProfile = AdminUserModel.fromJson(buildUser(
      id: 'user-4',
      email: 'profile-premium@example.com',
      username: 'Profile Premium',
      isPremium: true,
    ));

    final inactiveSub = AdminUserModel.fromJson(buildUser(
      id: 'user-5',
      email: 'inactive@example.com',
      username: 'Inactive',
      subscription: {
        'id': 'sub-2',
        'user_id': 'user-5',
        'status': 'inactive',
        'provider': 'aliolo',
        'expiry_date': '2024-12-31T00:00:00Z',
      },
    ));

    expect(premiumByProfile.isPremium, isTrue);
    expect(inactiveSub.isPremium, isFalse);
    expect(inactiveSub.subscription?.provider, 'aliolo');
  });
}
