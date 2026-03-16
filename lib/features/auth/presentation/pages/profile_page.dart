import 'package:aliolo/core/utils/io_utils.dart' if (dart.library.html) 'package:aliolo/core/utils/file_stub.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/auth/presentation/pages/manage_friends_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = getIt<AuthService>();
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
  }

  void _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
    );
    if (image != null) {
      // Check file size (Max 1MB for avatar)
      final sizeInBytes = await image.length();
      if (sizeInBytes > 1 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.t('file_too_large')}. ${context.t('max_size_is', args: {'size': '1'})}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

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
                      suffixIcon:
                          nameController.text.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  nameController.clear();
                                  setDialogState(() {});
                                },
                              )
                              : null,
                    ),
                    onChanged: (val) => setDialogState(() {}),
                    onSubmitted: (val) async {
                      if (val.trim().isNotEmpty) {
                        await _authService.updateUsername(val.trim());
                        if (mounted) Navigator.pop(context);
                      }
                    },
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
              icon: const Icon(Icons.person, color: appBarColor),
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
                context.t('daily_progress'),
                currentSessionColor,
              ),
              _buildDailyProgressCard(context, user, currentSessionColor),
              const SizedBox(height: 32),
              _buildSectionTitle(
                context,
                context.t('social'),
                currentSessionColor,
              ),
              Card(
                child: ListTile(
                  leading: Icon(Icons.people, color: currentSessionColor),
                  title: Text(context.t('manage_friends')),
                  subtitle: Text(context.t('manage_friends_desc')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ManageFriendsPage(),
                        ),
                      ),
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionTitle(
                context,
                context.t('testing_section'),
                currentSessionColor,
              ),
              _buildSettingsCard(context, currentSessionColor, user),
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
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDailyProgressCard(
    BuildContext context,
    UserModel user,
    Color color,
  ) {
    final progress = (user.dailyCompletions / user.dailyGoalCount).clamp(
      0.0,
      1.0,
    );
    final isGoalReached = user.dailyCompletions >= user.dailyGoalCount;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
        child: Row(
          children: [
            Icon(Icons.trending_up, size: 24, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.t('done_today'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${user.dailyCompletions.toStringAsFixed(1).replaceAll('.0', '')} / ${user.dailyGoalCount}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isGoalReached ? Colors.green : color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: color.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isGoalReached ? Colors.green : color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
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
                          suffixIcon:
                              passwordController.text.isNotEmpty
                                  ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      passwordController.clear();
                                      setDialogState(() {});
                                    },
                                  )
                                  : null,
                        ),
                        onChanged: (val) => setDialogState(() {}),
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
                      onPressed:
                          () => _handleDeleteConfirm(passwordController.text),
                      child: Text(
                        context.t('delete_account'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    Color color, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
            ],
            Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(BuildContext context, String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context, Color color, UserModel user) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.adjust, color: color),
            title: Text(context.t('next_day_goal')),
            subtitle: Text(
              context.t('goal_change_hint'),
              style: const TextStyle(fontSize: 12),
            ),
            trailing: Text(
              '${user.nextDailyGoal} ${context.plural('card', user.nextDailyGoal)}',
            ),
            onTap:
                () => _showValuePicker(
                  title: context.t('next_day_goal'),
                  initialValue: user.nextDailyGoal,
                  min: 5,
                  max: 50,
                  defaultValue: 20,
                  onSelected: (val) => _authService.updateNextDailyGoal(val),
                ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.school, color: color),
            title: Text(context.t('learn_session_size')),
            trailing: Text(
              '${user.learnSessionSize} ${context.plural('card', user.learnSessionSize)}',
            ),
            onTap:
                () => _showValuePicker(
                  title: context.t('learn_session_size'),
                  initialValue: user.learnSessionSize,
                  min: 5,
                  max: 50,
                  defaultValue: 20,
                  onSelected: (val) => _authService.updateLearnSessionSize(val),
                ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.quiz, color: color),
            title: Text(context.t('test_session_size')),
            trailing: Text(
              '${user.testSessionSize} ${context.plural('card', user.testSessionSize)}',
            ),
            onTap:
                () => _showValuePicker(
                  title: context.t('test_session_size'),
                  initialValue: user.testSessionSize,
                  min: 5,
                  max: 25,
                  defaultValue: 10,
                  onSelected: (val) => _authService.updateTestSessionSize(val),
                ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.view_headline, color: color),
            title: Text(context.t('options_count')),
            trailing: Text('${user.optionsCount}'),
            onTap:
                () => _showValuePicker(
                  title: context.t('options_count'),
                  initialValue: user.optionsCount,
                  min: 4,
                  max: 8,
                  defaultValue: 6,
                  onSelected: (val) => _authService.updateOptionsCount(val),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(UserModel user, Color currentSessionColor) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Row(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: currentSessionColor.withValues(alpha: 0.1),
                    backgroundImage:
                        user.avatarPath != null
                            ? (user.avatarPath!.startsWith('http') || kIsWeb
                                    ? NetworkImage(user.avatarPath!)
                                    : FileImage(dynamicFile(user.avatarPath!)))
                                as ImageProvider
                            : null,
                    child:
                        user.avatarPath == null
                            ? Icon(
                              Icons.person,
                              size: 60,
                              color: currentSessionColor,
                            )
                            : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: currentSessionColor,
                      child: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.username,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _showEditUsernameDialog(user.username),
                      ),
                    ],
                  ),
                  Text(
                    user.email,
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      _buildStat(context, '${user.totalXp}', context.t('xp')),
                      _buildStat(
                        context,
                        '${user.currentStreak}',
                        context.t('streak'),
                      ),
                      _buildStat(
                        context,
                        '${user.maxStreak}',
                        context.t('max_streak'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
