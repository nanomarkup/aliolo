import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
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

    // Sort: pending requests first
    data.sort((a, b) {
      if (a['status'] == 'pending' && b['status'] != 'pending') return -1;
      if (a['status'] != 'pending' && b['status'] == 'pending') return 1;
      return 0;
    });

    if (mounted) {
      setState(() {
        _friendships = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmCancelFriendship(
    int id,
    String username,
    String status,
  ) async {
    final isPending = status == 'pending';
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              isPending
                  ? context.t('cancel_request')
                  : context.t('remove_friend'),
            ),
            content: Text(
              isPending
                  ? '${context.t('cancel_request_confirm')} $username?'
                  : '${context.t('remove_friend_confirm')} $username?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.t('cancel')),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.t('confirm')),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _friendshipService.cancelFriendship(id);
      _loadFriendships();
    }
  }

  void _showAddFriendDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(context.t('add_friend_by_email')),
                  content: TextField(
                    controller: emailController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.t('email'),
                      suffixIcon:
                          emailController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  emailController.clear();
                                  setDialogState(() {});
                                },
                              )
                              : null,
                    ),
                    onChanged: (val) => setDialogState(() {}),
                    onSubmitted: (val) => _sendRequest(val),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.t('cancel')),
                    ),
                    TextButton(
                      onPressed: () => _sendRequest(emailController.text),
                      child: Text(context.t('send')),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _sendRequest(String email) async {
    final emailTrimmed = email.trim();
    if (emailTrimmed.isEmpty) return;

    final result = await _friendshipService.sendFriendRequest(emailTrimmed);
    if (mounted) {
      Navigator.pop(context);
      if (result == 'success') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('request_sent'))));
        _loadFriendships();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSessionColor = ThemeService().primaryColor;
    const appBarColor = Colors.white;

    return AlioloScrollablePage(
      title: Text(
        context.t('manage_friends'),
        style: const TextStyle(color: appBarColor),
      ),
      appBarColor: currentSessionColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
        IconButton(
          icon: const Icon(Icons.person_add, color: appBarColor),
          onPressed: _showAddFriendDialog,
        ),
      ],
      slivers: [
        if (_isLoading)
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_friendships.isEmpty)
          SliverFillRemaining(
            child: Center(child: Text(context.t('no_friends_found'))),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final f = _friendships[index];
              final isSender =
                  f['sender_id'] == _authService.currentUser?.serverId;
              final otherUser = isSender ? f['receiver'] : f['sender'];
              final status = f['status'];
              final id = f['id'];
              final avatarUrl = otherUser['avatar_url'] as String?;
              final email = otherUser['email'] ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage:
                        avatarUrl != null
                            ? (avatarUrl.startsWith('http') || kIsWeb
                                    ? NetworkImage(avatarUrl)
                                    : FileImage(File(avatarUrl)))
                                as ImageProvider
                            : null,
                    child: avatarUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(
                    otherUser['username'] ?? 'User',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (email.isNotEmpty)
                        Text(email, style: const TextStyle(fontSize: 12)),
                      if (status == 'pending')
                        Text(
                          isSender
                              ? context.t('request_sent_waiting')
                              : context.t('wants_to_be_friend'),
                        ),
                    ],
                  ),
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
                        onPressed:
                            () => _confirmCancelFriendship(
                              id,
                              otherUser['username'] ?? 'User',
                              status,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }, childCount: _friendships.length),
          ),
      ],
    );
  }
}
