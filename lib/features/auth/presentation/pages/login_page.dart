import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/settings/presentation/pages/about_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WindowListener {
  final _authService = getIt<AuthService>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailFocusNode = FocusNode();

  bool _isCreatingAccount = false;
  bool _isRecovering = false;
  int _recoveryStep = 0;
  bool _isLoading = false;

  Key _passwordKey = UniqueKey();
  Key _confirmKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) windowManager.addListener(this);
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _clearFields();
    _focusEmail();

    // Extra clear for web to fight browser autofill
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _passwordController.text = "";
          _confirmPasswordController.text = "";
        }
      });
    });
  }

  @override
  void onWindowClose() {
    if (!kIsWeb) windowManager.destroy();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (!ModalRoute.of(context)!.isCurrent) return false;
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_isRecovering) {
          _toggleRecovery();
        } else if (_isCreatingAccount) {
          _toggleMode();
        } else {
          if (!kIsWeb) windowManager.close();
        }
        return true; // Handled
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        // Only trigger global enter if no text field is focused or if handled by onSubmitted
        // For simplicity, we can let onSubmitted handle text fields and this handle buttons
        return false;
      }
    }
    return false;
  }

  void _focusEmail() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _emailFocusNode.requestFocus();
    });
  }

  void _clearFields() {
    _emailController.clear();
    _usernameController.clear();
    _passwordController.text = ""; // Force empty
    _confirmPasswordController.text = ""; // Force empty
    _codeController.clear();
    _passwordKey = UniqueKey();
    _confirmKey = UniqueKey();
  }

  void _toggleMode() {
    setState(() {
      _isCreatingAccount = !_isCreatingAccount;
      _isRecovering = false;
      _clearFields();
    });
    _focusEmail();
  }

  void _toggleRecovery() {
    setState(() {
      _isRecovering = !_isRecovering;
      _isCreatingAccount = false;
      _recoveryStep = 0;
      _clearFields();
    });
    _focusEmail();
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleAuth() async {
    final email = _emailController.text.trim();
    final pass = _passwordController.text;
    if (email.isEmpty || pass.isEmpty) {
      _showMsg(context.t('fill_all_fields'));
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (_isCreatingAccount) {
        final username = _usernameController.text.trim();
        final confirm = _confirmPasswordController.text;
        if (username.isEmpty || confirm.isEmpty) {
          _showMsg(context.t('fill_all_fields'));
          return;
        }
        if (pass != confirm) {
          _showMsg(context.t('passwords_dont_match'));
          return;
        }
        if (!_authService.isValidEmail(email)) {
          _showMsg(context.t('invalid_email'));
          return;
        }

        await _authService.createUser(username, email, pass);

        if (_authService.lastErrorMessage != null &&
            _authService.lastErrorMessage!.contains('confirmation')) {
          _showMsg('Account created! Please check your email to confirm.');
          _toggleMode();
          return;
        }
        _showMsg('Account created successfully!');
      }

      final success = await _authService.login(email, pass);
      if (success) {
        if (mounted)
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SubjectPage()),
          );
      } else {
        final err = _authService.lastErrorMessage ?? '';
        if (err.toLowerCase().contains('confirmed')) {
          _showMsg('Please confirm your email address before logging in.');
        } else {
          _showMsg(
            _authService.lastErrorMessage ?? context.t('invalid_password'),
          );
        }
      }
    } catch (e) {
      final err = _authService.lastErrorMessage ?? e.toString();
      if (err.toLowerCase().contains('confirmed')) {
        _showMsg('Please check your inbox and confirm your email.');
        if (_isCreatingAccount) _toggleMode();
      } else {
        _showMsg(err);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRecovery() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showMsg(context.t('fill_all_fields'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_recoveryStep == 0) {
        await _authService.sendResetCode(email);
        _showMsg('Reset code sent to $email (Mock: 123456)');
        setState(() => _recoveryStep = 1);
      } else {
        final code = _codeController.text.trim();
        final newPass = _passwordController.text;
        final confirm = _confirmPasswordController.text;
        if (code.isEmpty || newPass.isEmpty) {
          _showMsg(context.t('fill_all_fields'));
          return;
        }
        if (newPass != confirm) {
          _showMsg(context.t('passwords_dont_match'));
          return;
        }
        if (_authService.verifyResetCode(email, code)) {
          await _authService.finalizePasswordReset(email, newPass);
          _showMsg('Password updated successfully!');
          _toggleRecovery();
        } else {
          _showMsg(_authService.lastErrorMessage ?? 'Invalid reset code.');
        }
      }
    } catch (e) {
      _showMsg(_authService.lastErrorMessage ?? 'Recovery error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 60,
            child: DragToMoveArea(child: SizedBox.expand()),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AboutPage(),
                            ),
                          ),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Column(
                          children: [
                            const Icon(
                              Icons.account_circle,
                              size: 80,
                              color: Colors.orange,
                            ),
                            const Text(
                              'Aliolo',
                              style: TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (!_isRecovering) ...[
                      TextField(
                        focusNode: _emailFocusNode,
                        controller: _emailController,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: InputDecoration(
                          labelText: context.t('email'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        onSubmitted: (_) => _handleAuth(),
                      ),
                      const SizedBox(height: 12),
                      if (_isCreatingAccount) ...[
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: context.t('username'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.person),
                          ),
                          onSubmitted: (_) => _handleAuth(),
                          autofillHints: const [AutofillHints.username],
                        ),
                        const SizedBox(height: 12),
                      ],
                      TextField(
                        key: _passwordKey,
                        controller: _passwordController,
                        obscureText: true,
                        enableSuggestions: false,
                        autocorrect: false,
                        autofillHints: null, // Disable autofill hints
                        decoration: InputDecoration(
                          labelText: context.t('password'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock),
                        ),
                        onSubmitted: (_) => _handleAuth(),
                      ),
                      const SizedBox(height: 12),
                      if (_isCreatingAccount) ...[
                        TextField(
                          key: _confirmKey,
                          controller: _confirmPasswordController,
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          autofillHints: null, // Disable autofill hints
                          decoration: InputDecoration(
                            labelText: context.t('confirm_password'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_reset),
                          ),
                          onSubmitted: (_) => _handleAuth(),
                        ),
                        const SizedBox(height: 24),
                      ],
                      const SizedBox(height: 16),
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else ...[
                        ElevatedButton(
                          onPressed: _handleAuth,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _isCreatingAccount
                                ? context.t('create_account')
                                : context.t('login'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _toggleMode,
                          child: Text(
                            _isCreatingAccount
                                ? context.t('back_to_login')
                                : context.t('create_new_account'),
                          ),
                        ),
                        if (!_isCreatingAccount)
                          TextButton(
                            onPressed: _toggleRecovery,
                            child: Text(context.t('forgot_password')),
                          ),
                      ],
                    ] else ...[
                      Text(
                        context.t('restore_password'),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        focusNode: _emailFocusNode,
                        controller: _emailController,
                        enabled: _recoveryStep == 0,
                        decoration: InputDecoration(
                          labelText: context.t('email'),
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.email),
                        ),
                        onSubmitted: (_) => _handleRecovery(),
                      ),
                      const SizedBox(height: 12),
                      if (_recoveryStep == 1) ...[
                        TextField(
                          controller: _codeController,
                          decoration: const InputDecoration(
                            labelText: 'Reset Code',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pin),
                          ),
                          onSubmitted: (_) => _handleRecovery(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: _passwordKey,
                          controller: _passwordController,
                          obscureText: true,
                          autofillHints: null,
                          decoration: InputDecoration(
                            labelText: context.t('new_password'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                          onSubmitted: (_) => _handleRecovery(),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: _confirmKey,
                          controller: _confirmPasswordController,
                          obscureText: true,
                          autofillHints: null,
                          decoration: InputDecoration(
                            labelText: context.t('confirm_password'),
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_reset),
                          ),
                          onSubmitted: (_) => _handleRecovery(),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else ...[
                        ElevatedButton(
                          onPressed: _handleRecovery,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            _recoveryStep == 0
                                ? 'Send Code'
                                : 'Update Password',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _toggleRecovery,
                          child: Text(context.t('back_to_login')),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!kIsWeb)
                  const WindowControls(
                    onlyClose: true,
                    showSeparator: false,
                    color: Colors.orange,
                    iconSize: 28,
                    padding: false,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    if (!kIsWeb) windowManager.removeListener(this);
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    _emailFocusNode.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _codeController.dispose();
    super.dispose();
  }
}
