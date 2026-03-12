import 'dart:io';
import 'package:flutter/material.dart';
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

class _LeaderboardPageState extends State<LeaderboardPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _authService = AuthService();
  final _friendshipService = FriendshipService();
  
  List<UserModel> _globalUsers = [];
  List<UserModel> _friendUsers = [];
  bool _isLoading = true;

  int _currentPage = 0;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final global = await _authService.getLeaderboardData(page: _currentPage, pageSize: _pageSize);
    final friends = await _friendshipService.getFriendsLeaderboard();
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
      _currentPage = (rank - 1) ~/ _pageSize;
      await _loadData();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _nextPage() {
    if (_globalUsers.length == _pageSize) {
      setState(() {
        _currentPage++;
        _loadData();
      });
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
        _loadData();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const currentSessionColor = ThemeService.mainColor;
    const appBarColor = Colors.white;

    return ResizeWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: DragToMoveArea(
            child: SizedBox(
              width: double.infinity,
              child: Text(context.t('leaderboard'), style: const TextStyle(color: appBarColor)),
            ),
          ),
          backgroundColor: currentSessionColor,
          foregroundColor: appBarColor,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.school, color: appBarColor),
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SubjectPage()), (route) => false),
            ),
            IconButton(
              icon: const Icon(Icons.style, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCardsPage())),
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events, color: appBarColor),
              onPressed: () => _loadData(),
            ),
            IconButton(
              icon: const Icon(Icons.person, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
            ),
            const WindowControls(color: appBarColor, iconSize: 24),
          ],
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    Container(
                      color: Colors.grey.withValues(alpha: 0.05),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: currentSessionColor,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: currentSessionColor,
                        indicatorWeight: 3,
                        tabs: [
                          Tab(text: context.t('global')),
                          Tab(text: context.t('friends')),
                        ],
                      ),
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // Global List
                          Column(
                            children: [
                              Expanded(child: _buildList(_globalUsers, isGlobal: true)),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.chevron_left),
                                          onPressed: _currentPage > 0 ? _prevPage : null,
                                        ),
                                        Text('${context.t('page')} ${_currentPage + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                        IconButton(
                                          icon: const Icon(Icons.chevron_right),
                                          onPressed: _globalUsers.length == _pageSize ? _nextPage : null,
                                        ),
                                      ],
                                    ),
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
                          ),
                          // Friends List
                          _buildList(_friendUsers, isGlobal: false),
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
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isMe = user.serverId == _authService.currentUser?.serverId;
        final rank = isGlobal ? (_currentPage * _pageSize + index) : index;
        
        Color? rankColor;
        double elevation = 1;
        double verticalPadding = 0;
        Widget? trailing;

        if (rank == 0) {
          rankColor = const Color(0xFFFFD700); // Gold
          elevation = 6;
          verticalPadding = 8;
          trailing = const Icon(Icons.emoji_events, color: Color(0xFFFFD700), size: 32);
        } else if (rank == 1) {
          rankColor = const Color(0xFFC0C0C0); // Silver
          elevation = 4;
          verticalPadding = 4;
          trailing = const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 28);
        } else if (rank == 2) {
          rankColor = const Color(0xFFCD7F32); // Bronze
          elevation = 2;
          verticalPadding = 2;
          trailing = const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 24);
        }

        if (isMe && trailing == null) {
          trailing = const Icon(Icons.star, color: Colors.orange);
        }

        return Padding(
          padding: EdgeInsets.symmetric(vertical: verticalPadding),
          child: Card(
            elevation: elevation,
            color: isMe ? Colors.orange.withValues(alpha: 0.05) : null,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: rankColor != null ? BorderSide(color: rankColor, width: 2) : BorderSide.none,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              leading: Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: rankColor ?? Colors.grey[200],
                    backgroundImage: user.avatarPath != null 
                      ? (user.avatarPath!.startsWith('http') ? NetworkImage(user.avatarPath!) : FileImage(File(user.avatarPath!))) as ImageProvider
                      : null,
                    child: user.avatarPath == null 
                      ? Text(
                          '${rank + 1}', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            color: rankColor != null ? Colors.white : Colors.black87,
                            fontSize: 18
                          )
                        ) 
                      : null,
                  ),
                  if (user.avatarPath != null)
                    Positioned(
                      bottom: -2, right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: rankColor ?? Colors.grey[400], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                        child: Text('${rank + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                ],
              ),
              title: Text(
                user.username, 
                style: TextStyle(
                  fontWeight: rank < 3 || isMe ? FontWeight.bold : FontWeight.normal,
                  fontSize: rank < 3 ? 20 : 16,
                )
              ),
              subtitle: Text('${user.totalXp} XP • ${context.t('day_streak', args: {'count': user.currentStreak.toString()})}'),
              trailing: trailing,
            ),
          ),
        );
      },
    );
  }
}
