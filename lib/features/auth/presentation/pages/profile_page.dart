import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/user_model.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/settings/presentation/pages/premium_upgrade_page.dart';
import 'package:aliolo/features/documentation/presentation/pages/documentation_page.dart';
import 'package:aliolo/features/auth/presentation/pages/manage_friends_page.dart';
import 'package:aliolo/features/management/presentation/pages/users_page.dart';
import 'package:aliolo/data/services/feedback_service.dart';
import 'package:aliolo/core/widgets/premium_badge.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const String _adminUserId = 'usyeo7d2yzf2773';

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

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(context.t('upload_new_photo')),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadAvatar();
              },
            ),
            if (_authService.currentUser?.avatarPath != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  context.t('delete_avatar'),
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(context.t('delete_avatar')),
                      content: Text(context.t('delete_avatar_confirm')),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(context.t('cancel')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            context.t('delete'),
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _authService.deleteAvatar();
                    if (mounted) setState(() {});
                  }
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final codeController = TextEditingController();
    int step = 0; // 0: Input New Email & Password, 1: Input OTP
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(step == 0 ? context.t('edit_email') : 'Verify Email Change'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (step == 0) ...[
                  TextField(
                    controller: emailController,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'New Email',
                      hintText: context.t('enter_new_email'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.t('password'),
                      hintText: 'Enter current password',
                    ),
                  ),
                ] else ...[
                  Text('Enter the 6-digit code sent to ${emailController.text.trim()}'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Verification Code',
                      counterText: '',
                    ),
                  ),
                ],
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(context),
                child: Text(context.t('cancel')),
              ),
              ElevatedButton(
                onPressed: isLoading ? null : () async {
                  final newEmail = emailController.text.trim().toLowerCase();
                  if (step == 0) {
                    final pass = passwordController.text.trim();
                    if (newEmail.isEmpty || pass.isEmpty) return;
                    if (!_authService.isValidEmail(newEmail)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid email address')));
                      return;
                    }
                    
                    setDialogState(() => isLoading = true);
                    final success = await _authService.requestEmailChange(newEmail, pass);
                    setDialogState(() => isLoading = false);
                    
                    if (success) {
                      setDialogState(() => step = 1);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_authService.lastErrorMessage ?? 'Failed to request change')));
                    }
                  } else {
                    final code = codeController.text.trim();
                    if (code.length != 6) return;
                    
                    setDialogState(() => isLoading = true);
                    final success = await _authService.verifyEmailChange(newEmail, code);
                    setDialogState(() => isLoading = false);
                    
                    if (success && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email updated successfully!')));
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_authService.lastErrorMessage ?? 'Invalid code')));
                    }
                  }
                },
                child: Text(step == 0 ? 'Next' : 'Verify'),
              ),
            ],
          );
        },
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

  void _showUpdatePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(context.t('change_password')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: context.t('old_password'),
                    hintText: context.t('old_password_required'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.t('new_password'),
                    hintText: context.t('new_password_required'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: context.t('confirm_password'),
                    hintText: context.t('confirm_password_required'),
                  ),
                  onSubmitted: (_) => _handlePasswordUpdate(
                    passwordController.text,
                    confirmController.text,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('cancel')),
              ),
              TextButton(
                onPressed: () => _handlePasswordUpdate(
                  passwordController.text,
                  confirmController.text,
                ),
                child: Text(context.t('save')),
              ),
            ],
          ),
    );
  }

  void _handlePasswordUpdate(
    String password,
    String confirm,
  ) async {
    if (password.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('fill_all_fields'))),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('passwords_dont_match'))),
      );
      return;
    }

    try {
      await _authService.updatePassword(password);
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('password_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_authService.lastErrorMessage ?? e.toString())),
        );
      }
    }
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
          SnackBar(content: Text(_authService.lastErrorMessage ?? context.t('invalid_password_delete'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const appBarColor = Colors.white;

    return ListenableBuilder(
      listenable: Listenable.merge([TranslationService(), _authService]),
      builder: (context, _) {
        final user = _authService.currentUser;
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isSmallScreen = MediaQuery.of(context).size.width < 600;
        final currentSessionColor = ThemeService().primaryColor;

        final homeAction = IconButton(
          tooltip: context.t('home'),
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
          onPressed: () =>
              Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())),
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
          onPressed: () => setState(() {}),
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

        return AlioloScrollablePage(
          title: Text(
            context.t('profile'),
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
                context.t('account_and_management'),
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
                      leading: Icon(
                        user.isPremium ? Icons.workspace_premium : Icons.workspace_premium_outlined, 
                        color: user.isPremium ? Colors.amber : currentSessionColor,
                      ),
                      title: Text(user.isPremium ? context.t('manage_subscription') : context.t('premium_go')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const PremiumUpgradePage()),
                      ),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    Consumer<SubscriptionService>(
                      builder: (context, sub, _) {
                        final isPremium = sub.isPremium;
                        return SwitchListTile(
                          title: Row(
                            children: [
                              Text(context.t('public_profile')),
                              if (!isPremium) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                              ],
                            ],
                          ),
                          secondary: Icon(
                            Icons.emoji_events,
                            color: currentSessionColor,
                          ),
                          value: isPremium ? user.showOnLeaderboard : true,
                          onChanged: (val) {
                            if (!isPremium) {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumUpgradePage()));
                            } else {
                              _authService.updateLeaderboardPreference(val);
                            }
                          },
                        );
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
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
                    if (_authService.currentUser?.serverId == _adminUserId) ...[
                      ListTile(
                        leading: Icon(Icons.people_alt, color: currentSessionColor),
                        title: Text(context.t('users')),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const UsersPage()),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                    ],
                    ListTile(
                      leading: Icon(Icons.lock, color: currentSessionColor),
                      title: Text(context.t('change_password')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showUpdatePasswordDialog,
                    ),
                    if (!kIsWeb) ...[
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: Icon(Icons.restore, color: currentSessionColor),
                        title: const Text('Restore Purchases'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await getIt<SubscriptionService>().checkSubscriptionStatus();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(context.t('setting_saved'))),
                            );
                          }
                        },
                      ),
                    ],
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
                  if (user.username != 'Aliolo') ...[
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
                GestureDetector(
                  onTap: _showAvatarOptions,
                  child: _buildAvatar(user, 45, color),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _showAvatarOptions,
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
                    if (user.isPremium) ...[
                      const SizedBox(width: 8),
                      const PremiumBadge(size: 20),
                    ],
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
            _buildInfoItem(Icons.stars, '${user.totalXp}', context.t('total_xp'), getIt<ThemeService>().xp),
            _buildInfoItem(Icons.local_fire_department, '${user.currentStreak}', context.t('current_streak'), getIt<ThemeService>().streak),
            _buildInfoItem(Icons.emoji_events, '${user.maxStreak}', context.t('max_streak'), getIt<ThemeService>().amber),
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
    final isPremium = getIt<SubscriptionService>().isPremium;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.flag, color: color),
            title: Row(
              children: [
                Text(context.t('next_daily_goal')),
                if (!isPremium) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                ],
              ],
            ),
            subtitle: Text(context.t('next_daily_goal_desc')),
            trailing: Text(
              '${user.nextDailyGoal}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              if (!isPremium) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumUpgradePage()));
              } else {
                _showValuePicker(
                  title: context.t('next_daily_goal'),
                  initialValue: user.nextDailyGoal,
                  min: 5,
                  max: 100,
                  defaultValue: 20,
                  onSelected: (val) => _authService.updateNextDailyGoal(val),
                );
              }
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.slow_motion_video, color: color),
            title: Row(
              children: [
                Text(context.t('learn_session_size')),
                if (!isPremium) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                ],
              ],
            ),
            subtitle: Text(context.t('learn_session_size_desc')),
            trailing: Text(
              '${user.learnSessionSize}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              if (!isPremium) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumUpgradePage()));
              } else {
                _showValuePicker(
                  title: context.t('learn_session_size'),
                  initialValue: user.learnSessionSize,
                  min: 5,
                  max: 50,
                  defaultValue: 10,
                  onSelected: (val) => _authService.updateLearnSessionSize(val),
                );
              }
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.quiz, color: color),
            title: Row(
              children: [
                Text(context.t('test_session_size')),
                if (!isPremium) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                ],
              ],
            ),
            subtitle: Text(context.t('test_session_size_desc')),
            trailing: Text(
              '${user.testSessionSize}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              if (!isPremium) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumUpgradePage()));
              } else {
                _showValuePicker(
                  title: context.t('test_session_size'),
                  initialValue: user.testSessionSize,
                  min: 5,
                  max: 50,
                  defaultValue: 10,
                  onSelected: (val) => _authService.updateTestSessionSize(val),
                );
              }
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.view_list, color: color),
            title: Row(
              children: [
                Text(context.t('options_count')),
                if (!isPremium) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.workspace_premium, color: Colors.amber, size: 16),
                ],
              ],
            ),
            subtitle: Text(context.t('options_count_desc')),
            trailing: Text(
              '${user.optionsCount}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            onTap: () {
              if (!isPremium) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PremiumUpgradePage()));
              } else {
                _showValuePicker(
                  title: context.t('options_count'),
                  initialValue: user.optionsCount,
                  min: 3,
                  max: 9,
                  defaultValue: 6,
                  onSelected: (val) => _authService.updateOptionsCount(val),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
