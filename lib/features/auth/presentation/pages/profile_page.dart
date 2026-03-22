import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/auth/presentation/pages/manage_friends_page.dart';
import 'package:aliolo/features/management/presentation/pages/feedback_management_page.dart';
import 'package:aliolo/data/services/feedback_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = getIt<AuthService>();

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 512,
    );

    if (image != null) {
      await _authService.updateAvatarPath(image);
      if (mounted) setState(() {});
    }
  }

  void _showEditUsernameDialog(String currentName) {
    final nameController = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(context.t('edit_name')),
                  content: TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: context.t('enter_new_name'),
                    ),
                    onChanged: (val) => setDialogState(() {}),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.t('cancel')),
                    ),
                    TextButton(
                      onPressed: () async {
                        final newName = nameController.text.trim();
                        if (newName.isNotEmpty) {
                          await _authService.updateUsername(newName);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      child: Text(context.t('save')),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showEditEmailDialog(String currentEmail) {
    final emailController = TextEditingController(text: currentEmail);
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(context.t('edit_email')),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: emailController,
                        autofocus: true,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: context.t('enter_new_email'),
                        ),
                        onChanged: (val) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.t('email_change_notice'),
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.t('cancel')),
                    ),
                    TextButton(
                      onPressed: () async {
                        final newEmail = emailController.text.trim().toLowerCase();
                        if (newEmail.isNotEmpty && _authService.isValidEmail(newEmail)) {
                          try {
                            await _authService.updateEmail(newEmail);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(context.t('email_update_sent'))),
                              );
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        }
                      },
                      child: Text(context.t('save')),
                    ),
                  ],
                ),
          ),
    );
  }

  void _showValuePicker({
    required String title,
    required int initialValue,
    required int min,
    required int max,
    int? defaultValue,
    required Function(int) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        int tempValue = initialValue;
        return AlertDialog(
          title: Text(title),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tempValue.toString(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Slider(
                    value: tempValue.toDouble(),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    divisions: max - min,
                    activeColor: ThemeService().primaryColor,
                    onChanged:
                        (val) => setDialogState(() => tempValue = val.round()),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.t('cancel')),
            ),
            if (defaultValue != null)
              TextButton(
                onPressed: () {
                  onSelected(defaultValue);
                  Navigator.pop(context);
                },
                child: Text(context.t('default')),
              ),
            TextButton(
              onPressed: () {
                onSelected(tempValue);
                Navigator.pop(context);
              },
              child: Text(context.t('save')),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(context.t('delete_account')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.t('delete_account_confirm')),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.t('password'),
                    hintText: context.t('password_required'),
                  ),
                  onSubmitted: (val) => _handleDeleteConfirm(val),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('cancel')),
              ),
              TextButton(
                onPressed: () => _handleDeleteConfirm(passwordController.text),
                child: Text(
                  context.t('delete_account'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _handleDeleteConfirm(String password) async {
    final pass = password.trim();
    if (pass.isEmpty) return;

    final success = await _authService.deleteAccount(pass);
    if (mounted) {
      if (Navigator.canPop(context)) Navigator.pop(context); // Close dialog

      if (success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('account_deleted'))));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('invalid_password_delete'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;
    final currentSessionColor = ThemeService().primaryColor;

    return ListenableBuilder(
      listenable: Listenable.merge([TranslationService(), _authService]),
      builder: (context, _) {
        final user = _authService.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return AlioloScrollablePage(
          title: Text(
            context.t('profile'),
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
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardPage(),
                    ),
                  ),
            ),
            IconButton(
              icon: ValueListenableBuilder<bool>(
                valueListenable: getIt<FeedbackService>().pendingNotifications,
                builder: (context, hasNotif, _) {
                  return Badge(
                    isLabelVisible: hasNotif,
                    backgroundColor: Colors.amber,
                    child: const Icon(Icons.person, color: appBarColor),
                  );
                },
              ),
              onPressed: () => setState(() {}),
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
          body: Column(
            children: [
              const SizedBox(height: 24),
              _buildProfileHeader(user, currentSessionColor),
              const SizedBox(height: 32),
              _buildSectionTitle(
                context,
                context.t('testing_section'),
                currentSessionColor,
              ),
              _buildSettingsCard(context, currentSessionColor, user),
              const SizedBox(height: 32),
              _buildSectionTitle(
                context,
                context.t('support_and_management'),
                currentSessionColor,
              ),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.group, color: currentSessionColor),
                      title: Text(context.t('manage_friends')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ManageFriendsPage()),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.feedback, color: currentSessionColor),
                      title: Text(context.t('feedback_management_title')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FeedbackManagementPage(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _authService.logout();
                      if (mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                          (route) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(context.t('logout')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red,
                      elevation: 0,
                      minimumSize: const Size(160, 50),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _showDeleteAccountDialog,
                    icon: const Icon(Icons.delete_forever),
                    label: Text(context.t('delete_account')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(160, 50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                _buildAvatar(user, 45, color),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.username,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18, color: Colors.grey),
                      onPressed: () => _showEditUsernameDialog(user.username),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user.email,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: Colors.grey),
                      onPressed: () => _showEditEmailDialog(user.email),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildInfoItem(Icons.stars, '${user.totalXp}', context.t('total_xp'), Colors.orange),
            _buildInfoItem(Icons.local_fire_department, '${user.currentStreak}', context.t('current_streak'), Colors.red),
            _buildInfoItem(Icons.emoji_events, '${user.maxStreak}', context.t('max_streak'), Colors.amber),
            _buildInfoItem(Icons.track_changes, '${user.dailyCompletions.toInt()}/${user.dailyGoalCount}', context.t('daily_goal'), color),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildAvatar(UserModel user, double radius, Color color) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.1),
      backgroundImage:
          user.avatarPath != null ? NetworkImage(user.avatarPath!) : null,
      child:
          user.avatarPath == null
              ? Icon(Icons.person, size: radius, color: color)
              : null,
    );
  }

  Widget _buildSettingsCard(BuildContext context, Color color, UserModel user) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.flag, color: color),
            title: Text(context.t('next_daily_goal')),
            trailing: Text(
              '${user.nextDailyGoal}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap:
                () => _showValuePicker(
                  title: context.t('next_daily_goal'),
                  initialValue: user.nextDailyGoal,
                  min: 5,
                  max: 100,
                  defaultValue: 20,
                  onSelected: (val) => _authService.updateNextDailyGoal(val),
                ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.slow_motion_video, color: color),
            title: Text(context.t('learn_session_size')),
            trailing: Text(
              '${user.learnSessionSize}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap:
                () => _showValuePicker(
                  title: context.t('learn_session_size'),
                  initialValue: user.learnSessionSize,
                  min: 5,
                  max: 50,
                  defaultValue: 10,
                  onSelected: (val) => _authService.updateLearnSessionSize(val),
                ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.quiz, color: color),
            title: Text(context.t('test_session_size')),
            trailing: Text(
              '${user.testSessionSize}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap:
                () => _showValuePicker(
                  title: context.t('test_session_size'),
                  initialValue: user.testSessionSize,
                  min: 5,
                  max: 50,
                  defaultValue: 10,
                  onSelected: (val) => _authService.updateTestSessionSize(val),
                ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.view_list, color: color),
            title: Text(context.t('options_count')),
            trailing: Text(
              '${user.optionsCount}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap:
                () => _showValuePicker(
                  title: context.t('options_count'),
                  initialValue: user.optionsCount,
                  min: 2,
                  max: 12,
                  defaultValue: 6,
                  onSelected: (val) => _authService.updateOptionsCount(val),
                ),
          ),
        ],
      ),
    );
  }
}
