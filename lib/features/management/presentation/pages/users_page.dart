import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/data/models/admin_user_model.dart';
import 'package:aliolo/data/services/admin_users_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  static const String _adminUserId = 'usyeo7d2yzf2773';

  final _authService = getIt<AuthService>();
  final _usersService = getIt<AdminUsersService>();

  List<AdminUserModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  AdminUsersFilter _filter = AdminUsersFilter.all;

  bool get _isAdmin => _authService.currentUser?.serverId == _adminUserId;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _usersService.getAllUsers();
      users.sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<AdminUserModel> get _filteredUsers =>
      _users.where((user) => user.matchesFilter(_filter)).toList();

  String _formatDate(DateTime? date) {
    if (date == null) return context.t('not_available');
    final local = date.toLocal();
    return local.toIso8601String().split('T').first;
  }

  String _subscriptionStatusLabel(AdminUserModel user) {
    final subscription = user.subscription;
    if (subscription == null) return context.t('not_available');
    final status = subscription.status?.toLowerCase();
    if (status == 'active') return context.t('active');
    if (status == 'inactive') return context.t('inactive');
    return subscription.status ?? context.t('not_available');
  }

  Widget _buildFilterChip(AdminUsersFilter filter, String label) {
    final isSelected = _filter == filter;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      onSelected: (_) {
        setState(() => _filter = filter);
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Widget _buildUserCard(AdminUserModel user, Color currentSessionColor) {
    final isFake = user.isFake;
    final isPremium = user.isPremium;

    final badgeColor = isFake
        ? Colors.orange
        : isPremium
            ? Colors.amber
            : Colors.blueGrey;

    final badgeLabel = isFake
        ? context.t('fake_only')
        : isPremium
            ? context.t('premium_only')
            : context.t('free_only');

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: currentSessionColor.withValues(alpha: 0.1),
          child: Icon(Icons.person, color: currentSessionColor),
        ),
        title: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              user.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeLabel,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(user.email),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.t('personal_data'),
              style: TextStyle(
                color: currentSessionColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(context.t('username'), user.username.isNotEmpty ? user.username : context.t('not_available')),
          _buildInfoRow(context.t('email'), user.email),
          _buildInfoRow(context.t('total_xp'), '${user.profile.totalXp}'),
          _buildInfoRow(context.t('current_streak'), '${user.profile.currentStreak}'),
          _buildInfoRow(context.t('max_streak'), '${user.profile.maxStreak}'),
          _buildInfoRow(context.t('ui_language'), user.profile.uiLanguage),
          _buildInfoRow(context.t('default_language'), user.profile.defaultLanguage),
          _buildInfoRow(context.t('created_at'), _formatDate(user.profile.createdAt)),
          _buildInfoRow(context.t('updated_at'), _formatDate(user.profile.updatedAt)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.t('subscription_data'),
              style: TextStyle(
                color: currentSessionColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildInfoRow(context.t('status'), _subscriptionStatusLabel(user)),
          _buildInfoRow(
            context.t('provider'),
            user.subscription?.provider ?? context.t('not_available'),
          ),
          _buildInfoRow(
            context.t('expiry_date'),
            _formatDate(user.subscription?.expiryDate),
          ),
          _buildInfoRow(
            context.t('purchase_token'),
            user.subscription?.purchaseToken ?? context.t('not_available'),
          ),
          _buildInfoRow(
            context.t('order_id'),
            user.subscription?.orderId ?? context.t('not_available'),
          ),
          _buildInfoRow(
            context.t('product_id'),
            user.subscription?.productId ?? context.t('not_available'),
          ),
          _buildInfoRow(
            context.t('created_at'),
            _formatDate(user.subscription?.createdAt),
          ),
          _buildInfoRow(
            context.t('updated_at'),
            _formatDate(user.subscription?.updatedAt),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    const Color currentSessionColor = ThemeService.mainColor;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        final isSmallScreen = MediaQuery.of(context).size.width < 600;

        final homeAction = IconButton(
          tooltip: context.t('home'),
          icon: const Icon(Icons.school),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SubjectPage()),
            (route) => false,
          ),
        );
        final leaderboardAction = IconButton(
          tooltip: context.t('leaderboard'),
          icon: const Icon(Icons.emoji_events),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaderboardPage()),
          ),
        );
        final profileAction = IconButton(
          tooltip: context.t('profile'),
          icon: const Icon(Icons.person),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          ),
        );
        final settingsAction = IconButton(
          tooltip: context.t('settings'),
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          ),
        );

        return ResizeWrapper(
          child: Scaffold(
            extendBodyBehindAppBar: true,
            appBar: AlioloAppBar(
              title: Text(context.t('users'), style: const TextStyle(color: appBarColor)),
              backgroundColor: currentSessionColor,
              foregroundColor: appBarColor,
              actions: isSmallScreen
                  ? [homeAction, profileAction]
                  : [homeAction, leaderboardAction, profileAction, settingsAction],
              overflowActions: isSmallScreen ? [leaderboardAction, settingsAction] : null,
            ),
            body: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : !_isAdmin
                    ? Center(
                        child: Text(
                          context.t('not_available'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      )
                    : Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 980),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                const SizedBox(height: 24),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildFilterChip(AdminUsersFilter.all, context.t('filter_all')),
                                    _buildFilterChip(AdminUsersFilter.premium, context.t('premium_only')),
                                    _buildFilterChip(AdminUsersFilter.fake, context.t('fake_only')),
                                    _buildFilterChip(AdminUsersFilter.free, context.t('free_only')),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    '${_filteredUsers.length} / ${_users.length}',
                                    style: TextStyle(
                                      color: Theme.of(context).textTheme.bodySmall?.color,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: _errorMessage != null
                                      ? Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(_errorMessage!),
                                              const SizedBox(height: 12),
                                              ElevatedButton(
                                                onPressed: _loadUsers,
                                                child: Text(context.t('confirm')),
                                              ),
                                            ],
                                          ),
                                        )
                                      : _filteredUsers.isEmpty
                                          ? Center(child: Text(context.t('no_users_found')))
                                          : ListView.builder(
                                              itemCount: _filteredUsers.length,
                                              itemBuilder: (context, index) {
                                                return _buildUserCard(
                                                  _filteredUsers[index],
                                                  currentSessionColor,
                                                );
                                              },
                                            ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        );
      },
    );
  }
}
