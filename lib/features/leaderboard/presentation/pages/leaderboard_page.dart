import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/friendship_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/features/management/presentation/pages/manage_cards_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';

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
    _loadData();
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
    const Color currentSessionColor = ThemeService.mainColor;
    const appBarColor = Colors.white;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return AlioloPage(
          title: Text(
            context.t('leaderboard'),
            style: const TextStyle(color: appBarColor),
          ),
          appBarColor: currentSessionColor,
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
          body:
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
                          color: isDark ? Colors.grey[900] : Colors.white,
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
                            final isGlobalTab = _tabController.index == 0;
                            final currentPage =
                                isGlobalTab
                                    ? _currentGlobalPage
                                    : _currentFriendsPage;
                            final list =
                                isGlobalTab ? _globalUsers : _friendUsers;

                            return Row(
                              children: [
                                // Left: Pagination
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left),
                                        onPressed:
                                            currentPage > 0 ? _prevPage : null,
                                      ),
                                      Text(
                                        '${context.t('page')} ${currentPage + 1}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right),
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
                                    mainAxisAlignment: MainAxisAlignment.center,
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
                                            () => _tabController.animateTo(0),
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
                                            () => _tabController.animateTo(1),
                                      ),
                                    ],
                                  ),
                                ),
                                // Right: My Position
                                Expanded(
                                  flex: 2,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _jumpToMe,
                                        icon: const Icon(Icons.my_location),
                                        label: Text(context.t('my_position')),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: currentSessionColor,
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
        );
      },
    );
  }

  Widget _buildList(List<UserModel> users, {required bool isGlobal}) {
    if (users.isEmpty) return Center(child: Text(context.t('no_users_found')));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPage = isGlobal ? _currentGlobalPage : _currentFriendsPage;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
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
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side:
                isMe
                    ? const BorderSide(color: ThemeService.mainColor, width: 2)
                    : BorderSide.none,
          ),
          child: ListTile(
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    '#${rank + 1}',
                    style: TextStyle(
                      fontWeight:
                          rank < 3 ? FontWeight.bold : FontWeight.normal,
                      color: rank < 3 ? ThemeService.mainColor : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundImage:
                      user.avatarPath != null
                          ? (user.avatarPath!.startsWith('http')
                                  ? NetworkImage(user.avatarPath!)
                                  : FileImage(File(user.avatarPath!)))
                              as ImageProvider
                          : null,
                  child:
                      user.avatarPath == null ? const Icon(Icons.person) : null,
                ),
              ],
            ),
            title: Text(
              user.username + (isMe ? ' (${context.t('you')})' : ''),
              style: TextStyle(
                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                fontSize: rank < 3 ? 20 : 16,
              ),
            ),
            subtitle: Text('${user.totalXp} XP'),
            trailing: trailing,
          ),
        );
      },
    );
  }
}
