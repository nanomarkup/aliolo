import 'dart:io';
import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/friendship_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/management/presentation/pages/manage_cards_page.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  final _friendshipService = FriendshipService();

  List<UserModel> _globalUsers = [];
  List<UserModel> _friendUsers = [];
  bool _isLoading = true;

  int _currentGlobalPage = 0;
  int _currentFriendsPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
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

  Future<void> _jumpToMe() async {
    setState(() => _isLoading = true);
    final rank = await _authService.getMyGlobalRank();
    if (rank > 0) {
      if (_tabController.index == 0) {
        _currentGlobalPage = (rank - 1) ~/ _pageSize;
      }
      await _loadData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    final isGlobal = _tabController.index == 0;
    final list = isGlobal ? _globalUsers : _friendUsers;
    if (list.length == _pageSize) {
      setState(() {
        if (isGlobal)
          _currentGlobalPage++;
        else
          _currentFriendsPage++;
        _loadData();
      });
    }
  }

  void _prevPage() {
    final isGlobal = _tabController.index == 0;
    final currentPage = isGlobal ? _currentGlobalPage : _currentFriendsPage;
    if (currentPage > 0) {
      setState(() {
        if (isGlobal)
          _currentGlobalPage--;
        else
          _currentFriendsPage--;
        _loadData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color currentSessionColor = ThemeService.mainColor;
    const appBarColor = Colors.white;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ResizeWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AlioloAppBar(
          title: Text(
            context.t('leaderboard'),
            style: const TextStyle(color: appBarColor),
          ),
          backgroundColor: currentSessionColor,
          foregroundColor: appBarColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.school, color: appBarColor),
              onPressed:
                  () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubjectPage(),
                    ),
                    (route) => false,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events, color: appBarColor),
              onPressed: () => _loadData(),
            ),
            IconButton(
              icon: const Icon(Icons.collections_bookmark, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageCardsPage(),
                    ),
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.person, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                const SizedBox(height: 100),
                Expanded(
                  child:
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                            children: [
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: [
                                    _buildList(_globalUsers, isGlobal: true),
                                    _buildList(_friendUsers, isGlobal: false),
                                  ],
                                ),
                              ),
                              // Shared Bottom Panel
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color:
                                      isDark ? Colors.grey[900] : Colors.white,
                                  border: Border(
                                    top: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).dividerColor.withValues(alpha: 0.1),
                                    ),
                                  ),
                                ),
                                child: ListenableBuilder(
                                  listenable: _tabController,
                                  builder: (context, _) {
                                    final isGlobalTab =
                                        _tabController.index == 0;
                                    final currentPage =
                                        isGlobalTab
                                            ? _currentGlobalPage
                                            : _currentFriendsPage;
                                    final list =
                                        isGlobalTab
                                            ? _globalUsers
                                            : _friendUsers;

                                    return Row(
                                      children: [
                                        // Left: Pagination
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.chevron_left,
                                                ),
                                                onPressed:
                                                    currentPage > 0
                                                        ? _prevPage
                                                        : null,
                                              ),
                                              Text(
                                                '${context.t('page')} ${currentPage + 1}',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.chevron_right,
                                                ),
                                                onPressed:
                                                    list.length == _pageSize
                                                        ? _nextPage
                                                        : null,
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Center: Tab Selection
                                        Expanded(
                                          flex: 1,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  Icons.public,
                                                  color:
                                                      isGlobalTab
                                                          ? currentSessionColor
                                                          : Colors.grey,
                                                ),
                                                onPressed:
                                                    () => _tabController
                                                        .animateTo(0),
                                              ),
                                              IconButton(
                                                icon: Icon(
                                                  Icons.people,
                                                  color:
                                                      !isGlobalTab
                                                          ? currentSessionColor
                                                          : Colors.grey,
                                                ),
                                                onPressed:
                                                    () => _tabController
                                                        .animateTo(1),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Right: My Position
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              ElevatedButton.icon(
                                                onPressed: _jumpToMe,
                                                icon: const Icon(
                                                  Icons.my_location,
                                                ),
                                                label: Text(
                                                  context.t('my_position'),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      currentSessionColor,
                                                  foregroundColor: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<UserModel> users, {required bool isGlobal}) {
    if (users.isEmpty) return Center(child: Text(context.t('no_users_found')));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPage = isGlobal ? _currentGlobalPage : _currentFriendsPage;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isMe = user.serverId == _authService.currentUser?.serverId;
        final rank = (currentPage * _pageSize + index);

        Color? rankColor;
        double elevation = 1;
        double verticalPadding = 0;
        Widget? trailing;

        if (rank == 0) {
          rankColor = const Color(0xFFFFD700); // Gold
          elevation = 6;
          verticalPadding = 8;
          trailing = const Icon(
            Icons.emoji_events,
            color: Color(0xFFFFD700),
            size: 32,
          );
        } else if (rank == 1) {
          rankColor = const Color(0xFFC0C0C0); // Silver
          elevation = 4;
          verticalPadding = 4;
          trailing = const Icon(
            Icons.emoji_events,
            color: Color(0xFFC0C0C0),
            size: 28,
          );
        } else if (rank == 2) {
          rankColor = const Color(0xFFCD7F32); // Bronze
          elevation = 2;
          verticalPadding = 2;
          trailing = const Icon(
            Icons.emoji_events,
            color: Color(0xFFCD7F32),
            size: 24,
          );
        }

        if (isMe && trailing == null) {
          trailing = const Icon(Icons.star, color: Colors.orange);
        }

        return Padding(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Card(
            elevation: elevation,
            color:
                isMe
                    ? Colors.orange.withValues(alpha: 0.1)
                    : (isDark ? Colors.grey[850] : null),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side:
                  rankColor != null
                      ? BorderSide(color: rankColor, width: 2)
                      : BorderSide.none,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor:
                        rankColor ??
                        (isDark ? Colors.grey[700] : Colors.grey[200]),
                    backgroundImage:
                        user.avatarPath != null
                            ? (user.avatarPath!.startsWith('http')
                                    ? NetworkImage(user.avatarPath!)
                                    : FileImage(File(user.avatarPath!)))
                                as ImageProvider
                            : null,
                    child:
                        user.avatarPath == null
                            ? Text(
                              '${rank + 1}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color:
                                    rankColor != null
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white70
                                            : Colors.black87),
                                fontSize: 18,
                              ),
                            )
                            : null,
                  ),
                  if (user.avatarPath != null)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: rankColor ?? Colors.grey[400],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Text(
                          '${rank + 1}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              title: Text(
                user.username,
                style: TextStyle(
                  fontWeight:
                      rank < 3 || isMe ? FontWeight.bold : FontWeight.normal,
                  fontSize: rank < 3 ? 20 : 16,
                ),
              ),
              subtitle: Text('${user.totalXp} XP'),
              trailing: trailing,
            ),
          ),
        );
      },
    );
  }
}
