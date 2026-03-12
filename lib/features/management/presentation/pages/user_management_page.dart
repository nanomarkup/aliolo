import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/management/presentation/pages/manage_cards_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';

import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final _authService = AuthService();
  List<UserModel> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await _authService.getAllUsers();
    users.sort((a, b) => a.username.toLowerCase().compareTo(b.username.toLowerCase()));
    setState(() {
      _users = users;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    const currentSessionColor = ThemeService.mainColor;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return ResizeWrapper(
          child: Scaffold(
            appBar: AppBar(
              title: DragToMoveArea(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(context.t('manage_users'), style: const TextStyle(color: appBarColor)),
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
                  icon: const Icon(Icons.emoji_events, color: appBarColor),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())),
                ),
                IconButton(
                  icon: const Icon(Icons.style, color: appBarColor),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCardsPage())),
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
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      padding: const EdgeInsets.all(24),
                      child: Card(
                        elevation: 2,
                        child: ListView.separated(
                          itemCount: _users.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final user = _users[index];
                            final isMe = user.serverId == _authService.currentUser?.serverId;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: currentSessionColor.withValues(alpha: 0.1),
                                child: Icon(Icons.person, color: currentSessionColor),
                              ),
                              title: Text(
                                user.username + (isMe ? ' (${context.t('you_rank', args: {'rank': ''}).replaceAll(' #', '')})' : ''),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(user.email),
                            );
                          },
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
