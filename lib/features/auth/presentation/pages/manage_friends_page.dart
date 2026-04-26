import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/data/services/friendship_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';

import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';

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

    // Sort: pending/invited requests first
    data.sort((a, b) {
      final sA = a['status'];
      final sB = b['status'];
      if ((sA == 'pending' || sA == 'invited') && (sB != 'pending' && sB != 'invited')) return -1;
      if ((sA != 'pending' && sA != 'invited') && (sB == 'pending' || sB == 'invited')) return 1;
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
    dynamic id,
    String username,
    String status,
  ) async {
    final isPending = status == 'pending' || status == 'invited';
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

    try {
      final result = await _friendshipService.sendFriendRequest(emailTrimmed);
      if (mounted) {
        if (result == 'user_not_found') {
          // Close the "Add Friend By Email" dialog BEFORE showing the "Invite" confirmation
          Navigator.pop(context);

          final invite = await showDialog<bool>(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: Text(context.t('invite_user_title')),
                  content: Text(
                    context.t('invite_user_content', args: {'email': emailTrimmed}),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(context.t('cancel')),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(context.t('invite')),
                    ),
                  ],
                ),
          );

          if (invite == true) {
            try {
              final senderId = _authService.currentUser?.serverId;
              await _authService.inviteUserByEmail(emailTrimmed, senderId: senderId);

              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Invited and request sent!')));
                _loadFriendships();
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            }
          }
        } else if (result == 'success') {
          Navigator.pop(context); // Close the "Add Friend" dialog
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.t('request_sent'))));
          _loadFriendships();
        } else {
          // Keep the dialog open on other errors (like "Cannot add yourself")
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(result)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
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
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const SubjectPage()),
              );
            }
          },
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
              final status = f['status'];
              final id = f['id'];
              final isInvited = status == 'invited';
              
              final isSender =
                  f['sender_id'] == _authService.currentUser?.serverId;
              final otherUser = isSender ? f['receiver'] : f['sender'];
              
              if (otherUser == null && !isInvited) {
                return const Card(
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text('Unknown User (Profile missing)'),
                  ),
                );
              }

              final avatarUrl = isInvited ? null : otherUser?['avatar_url'] as String?;
              final email = isInvited ? (f['receiver_username'] ?? '') : (otherUser?['email'] ?? '');
              final username = isInvited ? (f['receiver_username'] ?? 'Invited User') : (otherUser?['username'] ?? 'User');

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: avatarUrl != null
                        ? ClipOval(
                            child: (avatarUrl.startsWith('http') || kIsWeb)
                                ? Image.network(
                                    avatarUrl,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Icon(isInvited ? Icons.mail_outline : Icons.person),
                                  )
                                : Image.file(
                                    dynamicFile(avatarUrl),
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Icon(isInvited ? Icons.mail_outline : Icons.person),
                                  ),
                          )
                        : Icon(isInvited ? Icons.mail_outline : Icons.person),
                  ),
                  title: Text(
                    username,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (email.isNotEmpty && email != username)
                        Text(email, style: const TextStyle(fontSize: 12)),
                      if (status == 'pending')
                        Text(
                          isSender
                              ? context.t('request_sent_waiting')
                              : context.t('wants_to_be_friend'),
                        ),
                      if (status == 'invited')
                        const Text('Invitation sent (awaiting registration)', style: TextStyle(fontStyle: FontStyle.italic)),
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
                              username,
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
