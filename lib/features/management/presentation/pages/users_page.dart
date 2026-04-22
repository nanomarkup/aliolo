import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/theme/aliolo_layout_tokens.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
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
  final _searchController = TextEditingController();

  List<AdminUserModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  AdminUsersFilter _filter = AdminUsersFilter.all;
  bool _showFakeUsers = false;

  bool get _isAdmin => _authService.currentUser?.serverId == _adminUserId;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    _searchController.addListener(_onSearchChanged);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final users = await _usersService.getAllUsers();
      users.sort(
        (a, b) =>
            a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
      );
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

  List<AdminUserModel> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();
    return _users.where((user) {
      // 1. Search filter
      final matchesSearch =
          query.isEmpty ||
          user.displayName.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
      if (!matchesSearch) return false;

      // 2. Fake users filter
      if (!_showFakeUsers && user.isFake) return false;

      // 3. Subscription status filter
      switch (_filter) {
        case AdminUsersFilter.all:
          return true;
        case AdminUsersFilter.free:
          return user.isFree;
        case AdminUsersFilter.premium:
          return user.isPremium;
        case AdminUsersFilter.fake:
          return user.isFake;
      }
    }).toList();
  }

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

  String _filterLabel(AdminUsersFilter filter) {
    switch (filter) {
      case AdminUsersFilter.all:
        return context.t('filter_all');
      case AdminUsersFilter.premium:
        return context.t('premium_only');
      case AdminUsersFilter.free:
        return context.t('free_only');
      case AdminUsersFilter.fake:
        return 'Fake Users';
    }
  }

  Widget _buildCompactDropdown({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
    bool matchAnchorWidth = true,
  }) {
    final validatedValue =
        items.containsKey(value)
            ? value
            : (items.isNotEmpty ? items.keys.first : '');
    final label = items[validatedValue] ?? '';

    return LayoutBuilder(
      builder: (context, box) {
        return PopupMenuButton<String>(
          constraints:
              matchAnchorWidth
                  ? BoxConstraints(
                    minWidth: box.maxWidth,
                    maxWidth: box.maxWidth,
                  )
                  : null,
          onSelected: onChanged,
          position: PopupMenuPosition.under,
          tooltip: '',
          color: Theme.of(context).colorScheme.surface,
          itemBuilder:
              (context) =>
                  items.entries
                      .map(
                        (e) => PopupMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value, {bool copyable = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: context.t('copy'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('info_copied'))),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHeaderControls(BuildContext context) {
    final currentPrimaryColor = ThemeService().primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: _buildCompactDropdown(
              value: _filter.name,
              items: {
                for (final filter in AdminUsersFilter.values)
                  filter.name: _filterLabel(filter),
              },
              onChanged: (value) {
                setState(() {
                  _filter = AdminUsersFilter.values.firstWhere(
                    (filter) => filter.name == value,
                    orElse: () => AdminUsersFilter.all,
                  );
                });
              },
            ),
          ),
          const SizedBox(width: AlioloLayoutTokens.compactRowSpacing),
          IconButton(
            tooltip: 'Show Fake Users',
            icon: Icon(
              _showFakeUsers ? Icons.face : Icons.face_outlined,
              color: _showFakeUsers ? currentPrimaryColor : Colors.grey,
            ),
            onPressed: () {
              setState(() => _showFakeUsers = !_showFakeUsers);
            },
            style: IconButton.styleFrom(
              backgroundColor:
                  _showFakeUsers
                      ? currentPrimaryColor.withValues(alpha: 0.1)
                      : null,
            ),
          ),
          const SizedBox(width: AlioloLayoutTokens.compactRowSpacing),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                isDense: true,
                hintText: context.t('search_users'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: Theme.of(context).cardColor.withValues(alpha: 0.5),
                suffixIcon:
                    _searchController.text.isEmpty
                        ? null
                        : IconButton(
                          tooltip: context.t('clear'),
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                          },
                        ),
              ),
            ),
          ),
          const SizedBox(width: AlioloLayoutTokens.compactRowSpacing),
          Text(
            '${_filteredUsers.length} / ${_users.length}',
            style: TextStyle(
              color: Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSubscriptionDialog(AdminUserModel user) async {
    String status =
        user.subscription?.status?.toLowerCase() == 'active'
            ? 'active'
            : 'inactive';
    DateTime? expiryDate = user.subscription?.expiryDate;
    int cardLimit = user.profile.cardLimit;

    final result = await showDialog<_SubscriptionEditResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final expiryLabel =
                expiryDate == null
                    ? context.t('not_available')
                    : _formatDate(expiryDate);

            return AlertDialog(
              title: Text(context.t('edit_user')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(user.email),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: status,
                      decoration: InputDecoration(
                        labelText: context.t('status'),
                        border: const OutlineInputBorder(),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'active',
                          child: Text(context.t('active')),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text(context.t('inactive')),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          status = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.t('expiry_date'),
                        border: const OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              expiryLabel,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    expiryDate ??
                                    DateTime.now().add(
                                      const Duration(days: 365),
                                    ),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  expiryDate = picked;
                                });
                              }
                            },
                            child: Text(context.t('pick_date')),
                          ),
                          if (expiryDate != null)
                            IconButton(
                              tooltip: context.t('clear'),
                              onPressed: () {
                                setDialogState(() {
                                  expiryDate = null;
                                });
                              },
                              icon: const Icon(Icons.clear),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: cardLimit.toString(),
                      decoration: InputDecoration(
                        labelText: context.t('card_limit'),
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        final val = int.tryParse(value);
                        if (val != null) {
                          cardLimit = val;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.t('provider'),
                        border: const OutlineInputBorder(),
                      ),
                      child: const Text('aliolo'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    final normalizedExpiry =
                        status == 'active'
                            ? (expiryDate ??
                                DateTime.now().add(const Duration(days: 365)))
                            : expiryDate;
                    Navigator.pop(
                      dialogContext,
                      _SubscriptionEditResult(
                        status: status,
                        expiryDate: normalizedExpiry,
                        cardLimit: cardLimit,
                      ),
                    );
                  },
                  child: Text(context.t('save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    try {
      if (result.status != (user.subscription?.status ?? 'inactive') || result.expiryDate != user.subscription?.expiryDate) {
        await _usersService.updateSubscription(
          userId: user.id,
          status: result.status,
          expiryDate: result.expiryDate,
        );
      }
      
      if (result.cardLimit != user.profile.cardLimit) {
        await _usersService.updateCardLimit(
          userId: user.id,
          limit: result.cardLimit,
        );
      }

      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('user_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Widget _buildUserCard(AdminUserModel user, Color currentSessionColor) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(
        bottom: AlioloLayoutTokens.compactTileBottomSpacing / 2,
      ),
      child: ExpansionTile(
        minTileHeight: 56,
        visualDensity: VisualDensity.standard,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: currentSessionColor.withValues(alpha: 0.1),
          backgroundImage:
              user.profile.avatarPath != null &&
                      user.profile.avatarPath!.isNotEmpty
                  ? NetworkImage(user.profile.avatarPath!)
                  : null,
          child:
              user.profile.avatarPath == null ||
                      user.profile.avatarPath!.isEmpty
                  ? Icon(Icons.person, color: currentSessionColor, size: 24)
                  : null,
        ),
        title: Text(
          user.displayName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            height: 1.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          tooltip: context.t('edit_subscription'),
          onPressed: () => _showEditSubscriptionDialog(user),
          icon: const Icon(Icons.edit_outlined),
          visualDensity: VisualDensity.standard,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
        ),
        subtitle: Text(
          user.email,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodySmall?.color,
            height: 1.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
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
          const SizedBox(height: 4),
          _buildInfoRow(context.t('user_id'), user.id, copyable: true),
          _buildInfoRow(
            context.t('username'),
            user.username.isNotEmpty
                ? user.username
                : context.t('not_available'),
          ),
          _buildInfoRow(context.t('email'), user.email, copyable: true),
          _buildInfoRow(context.t('total_xp'), '${user.profile.totalXp}'),
          _buildInfoRow(
            context.t('current_streak'),
            '${user.profile.currentStreak}',
          ),
          _buildInfoRow(context.t('max_streak'), '${user.profile.maxStreak}'),
          _buildInfoRow(context.t('ui_language'), user.profile.uiLanguage),
          _buildInfoRow(
            context.t('default_language'),
            user.profile.defaultLanguage,
          ),
          _buildInfoRow(
            context.t('created_at'),
            _formatDate(user.profile.createdAt),
          ),
          _buildInfoRow(
            context.t('updated_at'),
            _formatDate(user.profile.updatedAt),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 4),
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
            copyable: user.subscription?.purchaseToken != null,
          ),
          _buildInfoRow(
            context.t('order_id'),
            user.subscription?.orderId ?? context.t('not_available'),
            copyable: user.subscription?.orderId != null,
          ),
          _buildInfoRow(
            context.t('product_id'),
            user.subscription?.productId ?? context.t('not_available'),
            copyable: user.subscription?.productId != null,
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
    final currentSessionColor = ThemeService().primaryColor;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    final homeAction = IconButton(
      tooltip: context.t('home'),
      icon: const Icon(Icons.school, color: appBarColor),
      onPressed:
          () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const SubjectPage()),
            (route) => false,
          ),
    );
    final leaderboardAction = IconButton(
      tooltip: context.t('leaderboard'),
      icon: const Icon(Icons.emoji_events, color: appBarColor),
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeaderboardPage()),
          ),
    );
    final profileAction = IconButton(
      tooltip: context.t('profile'),
      icon: const Icon(Icons.person, color: appBarColor),
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProfilePage()),
          ),
    );
    final settingsAction = IconButton(
      tooltip: context.t('settings'),
      icon: const Icon(Icons.settings, color: appBarColor),
      onPressed:
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsPage()),
          ),
    );

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return AlioloScrollablePage(
          title: Text(
            context.t('users'),
            style: const TextStyle(color: appBarColor),
          ),
          appBarColor: currentSessionColor,
          actions:
              isSmallScreen
                  ? [homeAction, profileAction]
                  : [
                    homeAction,
                    leaderboardAction,
                    profileAction,
                    settingsAction,
                  ],
          overflowActions:
              isSmallScreen ? [leaderboardAction, settingsAction] : null,
          fixedBody:
              !_isAdmin
                  ? const SizedBox.shrink()
                  : _buildHeaderControls(context),
          slivers:
              !_isAdmin
                  ? [
                    SliverFillRemaining(
                      child: Center(
                        child: Text(
                          context.t('not_available'),
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  ]
                  : [
                    const SliverToBoxAdapter(child: SizedBox(height: 4)),
                    if (_isLoading)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_errorMessage != null)
                      SliverFillRemaining(
                        child: Center(
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
                        ),
                      )
                    else if (_filteredUsers.isEmpty)
                      SliverFillRemaining(
                        child: Center(child: Text(context.t('no_users_found'))),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _buildUserCard(
                            _filteredUsers[index],
                            currentSessionColor,
                          );
                        }, childCount: _filteredUsers.length),
                      ),
                  ],
        );
      },
    );
  }
}

class _SubscriptionEditResult {
  final String status;
  final DateTime? expiryDate;
  final int cardLimit;

  const _SubscriptionEditResult({
    required this.status,
    this.expiryDate,
    required this.cardLimit,
  });
}
