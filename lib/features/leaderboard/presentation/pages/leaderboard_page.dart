import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/friendship_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/documentation/presentation/pages/documentation_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/data/services/feedback_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/widgets/premium_badge.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();
  final _friendshipService = FriendshipService();
  late TabController _tabController;

  List<UserModel> _globalUsers = [];
  List<UserModel> _friendUsers = [];
  bool _isLoading = true;

  int _currentGlobalPage = 0;
  int _currentFriendsPage = 0;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadData();
    await _jumpToMe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final global = await _authService.getLeaderboardData(
      page: _currentGlobalPage,
      pageSize: _pageSize,
    );
    final friends = await _friendshipService.getFriendsLeaderboard(
      page: _currentFriendsPage,
      pageSize: _pageSize,
    );

    if (mounted) {
      setState(() {
        _globalUsers = global;
        _friendUsers = friends;
        _isLoading = false;
      });
    }
  }

  void _nextPage() {
    if (_tabController.index == 0) {
      _currentGlobalPage++;
    } else {
      _currentFriendsPage++;
    }
    _loadData();
  }

  void _prevPage() {
    if (_tabController.index == 0) {
      if (_currentGlobalPage > 0) _currentGlobalPage--;
    } else {
      if (_currentFriendsPage > 0) _currentFriendsPage--;
    }
    _loadData();
  }

  Future<void> _jumpToMe() async {
    setState(() => _isLoading = true);
    final myRank = await _authService.getMyGlobalRank();
    if (myRank != null) {
      _currentGlobalPage = (myRank - 1) ~/ _pageSize;
      _tabController.animateTo(0);
      await _loadData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;

    return ListenableBuilder(
      listenable: Listenable.merge([TranslationService(), _authService]),
      builder: (context, _) {
        final isGlobalTab = _tabController.index == 0;
        final currentPage = isGlobalTab ? _currentGlobalPage : _currentFriendsPage;
        final currentList = isGlobalTab ? _globalUsers : _friendUsers;

        final isSmallScreen = MediaQuery.of(context).size.width < 600;
        final currentSessionColor = ThemeService().primaryColor;

        final homeAction = IconButton(
          tooltip: context.t('home') ?? 'Home',
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
          onPressed: () => _loadData(),
        );
        final profileAction = IconButton(
          tooltip: context.t('profile'),
          icon: ValueListenableBuilder<bool>(
            valueListenable: getIt<FeedbackService>().pendingNotifications,
            builder: (context, hasNotif, _) {
              return Badge(
                isLabelVisible: hasNotif,
                backgroundColor: Colors.amber,
                child: const Icon(Icons.person),
              );
            },
          ),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
          },
        );
        final settingsAction = IconButton(
          tooltip: context.t('settings'),
          icon: const Icon(Icons.settings),
          onPressed: () =>
              Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
        );
        final docAction = (_authService.currentUser?.showDocumentation ?? true)
            ? IconButton(
              tooltip: context.t('documentation'),
              icon: const Icon(Icons.help_outline),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DocumentationPage()),
              ),
            )
            : null;

        return AlioloPage(
          title: Text(
            context.t('leaderboard'),
            style: const TextStyle(color: appBarColor, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          appBarColor: currentSessionColor,
          actions: isSmallScreen
              ? [homeAction, profileAction]
              : [
                homeAction,
                leaderboardAction,
                profileAction,
                settingsAction,
                if (docAction != null) docAction,
              ],
          overflowActions: isSmallScreen
              ? [
                leaderboardAction,
                settingsAction,
                if (docAction != null) docAction,
              ]
              : null,
          body: Column(
            children: [
              const SizedBox(height: 24),
              // Top Controls
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    Center(
                      child: SegmentedButton<int>(
                        segments: [
                          ButtonSegment(
                            value: 0,
                            label: Text(context.t('filter_all')),
                            icon: const Icon(Icons.public),
                          ),
                          ButtonSegment(
                            value: 1,
                            label: Text(context.t('manage_friends')),
                            icon: const Icon(Icons.people),
                          ),
                        ],
                        selected: {_tabController.index},
                        onSelectionChanged: (Set<int> newSelection) {
                          _tabController.animateTo(newSelection.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: currentPage > 0 ? _prevPage : null,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).cardColor.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${context.t('page')} ${currentPage + 1}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed:
                              currentList.length == _pageSize
                                  ? _nextPage
                                  : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child:
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : TabBarView(
                          controller: _tabController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            _buildList(_globalUsers, isGlobal: true),
                            _buildList(_friendUsers, isGlobal: false),
                          ],
                        ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(List<UserModel> users, {required bool isGlobal}) {
    if (users.isEmpty) return Center(child: Text(context.t('no_users_found')));
    final currentPage = isGlobal ? _currentGlobalPage : _currentFriendsPage;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 32),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isMe = user.serverId == _authService.currentUser?.serverId;
        final rank = (currentPage * _pageSize + index);

        Widget? trailing;
        if (rank < 3) {
          final colors = [Colors.amber, Colors.blueGrey[300]!, Colors.orange];
          trailing = Icon(Icons.emoji_events, color: colors[rank], size: 32);
        }

        return Card(
          elevation: isMe ? 4 : 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side:
                isMe
                    ? BorderSide(color: ThemeService().primaryColor, width: 2)
                    : BorderSide.none,
          ),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 35,
                  child: Text(
                    '#${rank + 1}',
                    style: TextStyle(
                      fontWeight:
                          rank < 3 ? FontWeight.bold : FontWeight.normal,
                      color:
                          rank < 3 ? ThemeService().primaryColor : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundImage:
                      user.avatarPath != null
                          ? NetworkImage(user.avatarPath!)
                          : null,
                  child:
                      user.avatarPath == null ? const Icon(Icons.person) : null,
                ),
              ],
            ),
            title: Row(
              children: [
                Text(
                  user.username + (isMe ? ' (${context.t('you')})' : ''),
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                    fontSize: rank < 3 ? 18 : 16,
                  ),
                ),
                if (user.isPremium) ...[
                  const SizedBox(width: 6),
                  const PremiumBadge(size: 14),
                ],
              ],
            ),
            subtitle: Text('${user.totalXp} XP'),
            trailing: trailing,
          ),
        );
      },
    );
  }
}
