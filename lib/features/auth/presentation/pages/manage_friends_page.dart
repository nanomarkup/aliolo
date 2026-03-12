import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/data/services/friendship_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';

class ManageFriendsPage extends StatefulWidget {
  const ManageFriendsPage({super.key});

  @override
  State<ManageFriendsPage> createState() => _ManageFriendsPageState();
}

class _ManageFriendsPageState extends State<ManageFriendsPage> {
  final _friendshipService = FriendshipService();
  final _authService = AuthService();
  List<Map<String, dynamic>> _friendships = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriendships();
  }

  Future<void> _loadFriendships() async {
    setState(() => _isLoading = true);
    final data = await _friendshipService.getFriendships();
    if (mounted) {
      setState(() {
        _friendships = data;
        _isLoading = false;
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
              child: Text(context.t('manage_friends'), style: const TextStyle(color: appBarColor)),
            ),
          ),
          backgroundColor: currentSessionColor,
          foregroundColor: appBarColor,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: appBarColor),
              onPressed: () => Navigator.pop(context),
            ),
            const WindowControls(color: appBarColor, iconSize: 24),
          ],
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _friendships.isEmpty 
            ? Center(child: Text(context.t('no_friends_found')))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _friendships.length,
                itemBuilder: (context, index) {
                  final f = _friendships[index];
                  final isSender = f['sender_id'] == _authService.currentUser?.serverId;
                  final otherUser = isSender ? f['receiver'] : f['sender'];
                  final status = f['status'];
                  final id = f['id'];

                  return Card(
                    child: ListTile(
                      title: Text(otherUser['username'] ?? 'User'),
                      subtitle: Text(status == 'pending' 
                        ? (isSender ? context.t('request_sent_waiting') : context.t('wants_to_be_friend')) 
                        : context.t('friend')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (status == 'pending' && !isSender)
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () async {
                                await _friendshipService.acceptFriendRequest(id);
                                _loadFriendships();
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () async {
                              await _friendshipService.cancelFriendship(id);
                              _loadFriendships();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
