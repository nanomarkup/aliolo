import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/di/service_locator.dart';
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
        (a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
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
      final matchesSearch = query.isEmpty ||
          user.displayName.toLowerCase().contains(query) ||
          user.username.toLowerCase().contains(query) ||
          user.email.toLowerCase().contains(query);
      return user.matchesFilter(_filter) && matchesSearch;
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
      case AdminUsersFilter.fake:
        return context.t('fake_only');
      case AdminUsersFilter.free:
        return context.t('free_only');
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
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

  Widget _buildHeaderControls(BuildContext context) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${_filteredUsers.length} / ${_users.length}',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 190,
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
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: context.t('search_users'),
                      hintText: context.t('search_users'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditSubscriptionDialog(AdminUserModel user) async {
    String status = user.subscription?.status?.toLowerCase() == 'active' ? 'active' : 'inactive';
    DateTime? expiryDate = user.subscription?.expiryDate;

    final result = await showDialog<_SubscriptionEditResult>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final expiryLabel = expiryDate == null
                ? context.t('not_available')
                : _formatDate(expiryDate);

            return AlertDialog(
              title: Text(context.t('edit_subscription')),
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
                                initialDate: expiryDate ?? DateTime.now().add(const Duration(days: 365)),
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
                            ? (expiryDate ?? DateTime.now().add(const Duration(days: 365)))
                            : expiryDate;
                    Navigator.pop(
                      dialogContext,
                      _SubscriptionEditResult(status: status, expiryDate: normalizedExpiry),
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
      await _usersService.updateSubscription(
        userId: user.id,
        status: result.status,
        expiryDate: result.expiryDate,
      );
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('subscription_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Widget _buildUserCard(AdminUserModel user, Color currentSessionColor) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 6),
      child: ExpansionTile(
        dense: true,
        visualDensity: VisualDensity.compact,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        leading: CircleAvatar(
          backgroundColor: currentSessionColor.withValues(alpha: 0.1),
          child: Icon(Icons.person, color: currentSessionColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: context.t('edit_subscription'),
              onPressed: () => _showEditSubscriptionDialog(user),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
        subtitle: Text(
          user.email,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
          const SizedBox(height: 6),
          _buildInfoRow(
            context.t('username'),
            user.username.isNotEmpty ? user.username : context.t('not_available'),
          ),
          _buildInfoRow(context.t('email'), user.email),
          _buildInfoRow(context.t('total_xp'), '${user.profile.totalXp}'),
          _buildInfoRow(context.t('current_streak'), '${user.profile.currentStreak}'),
          _buildInfoRow(context.t('max_streak'), '${user.profile.maxStreak}'),
          _buildInfoRow(context.t('ui_language'), user.profile.uiLanguage),
          _buildInfoRow(context.t('default_language'), user.profile.defaultLanguage),
          _buildInfoRow(context.t('created_at'), _formatDate(user.profile.createdAt)),
          _buildInfoRow(context.t('updated_at'), _formatDate(user.profile.updatedAt)),
          const SizedBox(height: 10),
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
          const SizedBox(height: 6),
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
    final currentSessionColor = ThemeService().primaryColor;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return AlioloScrollablePage(
          title: Text(
            context.t('users'),
            style: const TextStyle(color: appBarColor),
          ),
          appBarColor: currentSessionColor,
          actions: [
            IconButton(
              tooltip: context.t('profile'),
              icon: const Icon(Icons.person, color: appBarColor),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              ),
            ),
            IconButton(
              tooltip: context.t('settings'),
              icon: const Icon(Icons.settings, color: appBarColor),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              ),
            ),
          ],
          overflowActions: [
            IconButton(
              tooltip: context.t('home'),
              icon: const Icon(Icons.school, color: appBarColor),
              onPressed: () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SubjectPage()),
                (route) => false,
              ),
            ),
            IconButton(
              tooltip: context.t('leaderboard'),
              icon: const Icon(Icons.emoji_events, color: appBarColor),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LeaderboardPage()),
              ),
            ),
          ],
          fixedBody: !_isAdmin ? const SizedBox.shrink() : _buildHeaderControls(context),
          slivers: !_isAdmin
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
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          return _buildUserCard(
                            _filteredUsers[index],
                            currentSessionColor,
                          );
                        },
                        childCount: _filteredUsers.length,
                      ),
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

  const _SubscriptionEditResult({
    required this.status,
    this.expiryDate,
  });
}
