import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/theme/aliolo_theme.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/settings/presentation/pages/about_page.dart';
import 'package:aliolo/data/services/friendship_service.dart';
import 'package:aliolo/features/auth/presentation/pages/manage_friends_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = getIt<AuthService>();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _codeController = TextEditingController();
  final _emailFocusNode = FocusNode();

  bool _isCreatingAccount = false;
  int _signupStep = 0; // 0: Email, 1: OTP, 2: Details
  String? _inviteToken;
  bool _isRecovering = false;
  int _recoveryStep = 0;
  bool _isLoading = false;

  Key _passwordKey = UniqueKey();
  Key _confirmKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _clearFields();
    _focusEmail();

    _authService.addListener(_syncWithServiceState);
    _syncWithServiceState();

    _checkDeepLink();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _passwordController.text = "";
          _confirmPasswordController.text = "";
        }
      });
    });
  }

  void _checkDeepLink() {
    if (!kIsWeb) return;
    final invite = _authService.inviteToken;
    if (invite != null && _inviteToken == null) {
      _handleInvite(invite);
    }
  }

  Future<void> _handleInvite(String token) async {
    setState(() => _isLoading = true);
    
    // Auto-logout if a user is already logged in
    if (_authService.currentUser != null) {
      await _authService.logout();
    }

    final data = await _authService.verifyInvite(token);
    setState(() => _isLoading = false);

    if (data != null) {
      setState(() {
        _isCreatingAccount = true;
        _signupStep = 2; // Direct to details
        _inviteToken = data['token'];
        _emailController.text = data['email'] ?? '';
      });
      _showMsg('Welcome! Complete your profile to join aliolo.');
    } else {
      _showMsg('Invalid or expired invitation link.');
    }
  }

  void _syncWithServiceState() {
    if (_authService.isPasswordRecoveryFlow || _authService.isInviteFlow) {
      if (mounted) {
        setState(() {
          if (_authService.isPasswordRecoveryFlow) {
            _isRecovering = true;
            _recoveryStep = 1;
          }
          if (_authService.isInviteFlow) {
             _isCreatingAccount = true;
             _signupStep = 2;
             _inviteToken = _authService.inviteToken;
          }
          final sessionEmail = _authService.currentSessionEmail;
          if (sessionEmail != null) {
            _emailController.text = sessionEmail;
          }
        });
      }
    }
  }

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
          if (_inviteToken != null) {
            _toggleMode();
          } else if (_signupStep > 0) {
            setState(() => _signupStep--);
          } else {
            _toggleMode();
          }
        } else {
          if (!kIsWeb) windowManager.close();
        }
        return true;
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
    _passwordController.text = "";
    _confirmPasswordController.text = "";
    _codeController.clear();
    _passwordKey = UniqueKey();
    _confirmKey = UniqueKey();
    _signupStep = 0;
  }

  void _toggleMode() {
    setState(() {
      _isCreatingAccount = !_isCreatingAccount;
      _isRecovering = false;
      _signupStep = 0;
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
    if (email.isEmpty) {
      _showMsg(context.t('fill_all_fields'));
      return;
    }

    if (!_authService.isValidEmail(email)) {
      _showMsg(context.t('invalid_email'));
      return;
    }

    if (_isCreatingAccount) {
      if (_signupStep == 0) {
        setState(() => _isLoading = true);
        final success = await _authService.requestOtp(email);
        setState(() => _isLoading = false);
        if (success) {
          setState(() => _signupStep = 1);
          _showMsg('Verification code sent to $email');
        } else {
          final err = _authService.lastErrorMessage ?? '';
          if (err.contains('exists')) {
            _showMsg('User with this email already exists. Please log in instead.');
          } else {
            _showMsg(err.isNotEmpty ? err : 'Failed to send verification code');
          }
        }
        return;
      }

      if (_signupStep == 1) {
        final code = _codeController.text.trim();
        if (code.length != 6) {
          _showMsg('Please enter the 6-digit code');
          return;
        }
        setState(() => _isLoading = true);
        final success = await _authService.verifyOtp(email, code);
        setState(() => _isLoading = false);
        if (success) {
          setState(() => _signupStep = 2);
        } else {
          _showMsg(_authService.lastErrorMessage ?? 'Invalid code');
        }
        return;
      }

      // Step 2: Finalize signup
      final username = _usernameController.text.trim();
      final pass = _passwordController.text;
      final confirm = _confirmPasswordController.text;
      
      if (username.isEmpty || pass.isEmpty) {
        _showMsg(context.t('fill_all_fields'));
        return;
      }

      // If it's a normal signup, we require confirm.
      // If it's an invite and user left confirm empty but filled others, we'll allow it if the field was hidden (but it shouldn't be).
      if (confirm.isEmpty && _inviteToken == null) {
        _showMsg(context.t('fill_all_fields'));
        return;
      }

      if (confirm.isNotEmpty && pass != confirm) {
        _showMsg(context.t('passwords_dont_match'));
        return;
      }

      setState(() => _isLoading = true);
      
      try {
        if (_inviteToken != null) {
          await _authService.createUserWithInvite(username, email, pass, _inviteToken!);
        } else {
          await _authService.createUser(username, email, pass);
        }
        
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SubjectPage()),
          );
        }
      } catch (e) {
        _showMsg(_authService.lastErrorMessage ?? e.toString());
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
      return;
    }

    // Login flow
    final pass = _passwordController.text;
    if (pass.isEmpty) {
      _showMsg(context.t('fill_all_fields'));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final success = await _authService.login(email, pass);
      if (success) {
        if (mounted) {
          final hasPending = await FriendshipService().hasPendingRequests();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => hasPending ? const ManageFriendsPage() : const SubjectPage(),
              ),
            );
          }
        }
      } else {
        _showMsg(_authService.lastErrorMessage ?? context.t('invalid_password'));
      }
    } catch (e) {
      _showMsg(_authService.lastErrorMessage ?? e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleRecovery() async {
    final email = _emailController.text.trim();
    if (_recoveryStep == 0 && !_authService.isPasswordRecoveryFlow) {
      if (email.isEmpty) {
        _showMsg(context.t('fill_all_fields'));
        return;
      }
    }
    setState(() => _isLoading = true);
    try {
      if (_recoveryStep == 0) {
        final success = await _authService.sendResetCode(email);
        if (success) {
          _showMsg('Reset code sent to $email. Please check your inbox.');
          setState(() => _recoveryStep = 1);
        } else {
          _showMsg(_authService.lastErrorMessage ?? 'Failed to send reset code');
        }
      } else {
        final code = _codeController.text.trim();
        final newPass = _passwordController.text;
        final confirm = _confirmPasswordController.text;
        
        if (code.isEmpty || newPass.isEmpty || confirm.isEmpty) {
          _showMsg(context.t('fill_all_fields'));
          return;
        }
        if (newPass != confirm) {
          _showMsg(context.t('passwords_dont_match'));
          return;
        }
        
        final success = await _authService.finalizePasswordReset(email, code, newPass);
        if (success) {
          _showMsg('Password updated successfully!');
          _authService.clearRecoveryFlow();
          _toggleRecovery();
        } else {
          _showMsg(_authService.lastErrorMessage ?? 'Invalid or expired reset code.');
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
    final themeService = getIt<ThemeService>();
    final authService = context.watch<AuthService>();
    final bool isActuallyRecovering = _isRecovering || authService.isPasswordRecoveryFlow;
    final int effectiveStep = authService.isPasswordRecoveryFlow ? 1 : _recoveryStep;

    if (authService.isPasswordRecoveryFlow && _recoveryStep == 0) {
       WidgetsBinding.instance.addPostFrameCallback((_) {
         if (mounted && _recoveryStep == 0) {
           _syncWithServiceState();
         }
       });
    }

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final mainColor = themeService.getSystemColor(Brightness.light);

        return Theme(
          data: AlioloTheme.build(
            seedColor: mainColor,
            brightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
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
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/app_icon.png',
                                height: 120,
                                fit: BoxFit.contain,
                              ),
                              Transform.translate(
                                offset: const Offset(0, -16),
                                child: Column(
                                  children: [
                                    Text(
                                      'aliolo',
                                      style: GoogleFonts.poppins(
                                        fontSize: 80,
                                        fontWeight: FontWeight.w500,
                                        color: mainColor,
                                        letterSpacing: 4.0,
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(0, -20),
                                      child: Text(
                                        context.t('about_tagline'),
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.roboto(
                                          fontSize: 14,
                                          color: mainColor,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          if (!isActuallyRecovering) ...[
                            if (!_isCreatingAccount || _signupStep == 0) ...[
                              TextField(
                                focusNode: _emailFocusNode,
                                controller: _emailController,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: const [AutofillHints.email],
                                readOnly: _isCreatingAccount && _signupStep > 0,
                                decoration: InputDecoration(
                                  labelText: context.t('email'),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.email),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: mainColor, width: 2),
                                  ),
                                  labelStyle: TextStyle(
                                    color: _emailFocusNode.hasFocus ? mainColor : null,
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                onSubmitted: (_) => _handleAuth(),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_isCreatingAccount && _signupStep == 1) ...[
                              Text(
                                'Check your email for code',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: mainColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: _codeController,
                                decoration: InputDecoration(
                                  labelText: 'Verification Code',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.pin),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: mainColor, width: 2),
                                  ),
                                ),
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(6),
                                ],
                                onSubmitted: (_) => _handleAuth(),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_isCreatingAccount && _signupStep == 2) ...[
                              TextField(
                                controller: _usernameController,
                                decoration: InputDecoration(
                                  labelText: context.t('username'),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.person),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: mainColor, width: 2),
                                  ),
                                ),
                                onSubmitted: (_) => _handleAuth(),
                                autofillHints: const [AutofillHints.username],
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (!_isCreatingAccount || _signupStep == 2) ...[
                              TextField(
                                key: _passwordKey,
                                controller: _passwordController,
                                obscureText: true,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: null,
                                decoration: InputDecoration(
                                  labelText: context.t('password'),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lock),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: mainColor, width: 2),
                                  ),
                                ),
                                onSubmitted: (_) => _handleAuth(),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_isCreatingAccount && _signupStep == 2) ...[
                              TextField(
                                key: _confirmKey,
                                controller: _confirmPasswordController,
                                obscureText: true,
                                enableSuggestions: false,
                                autocorrect: false,
                                autofillHints: null,
                                decoration: InputDecoration(
                                  labelText: context.t('confirm_password'),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lock_reset),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: mainColor, width: 2),
                                  ),
                                ),
                                onSubmitted: (_) => _handleAuth(),
                              ),
                              const SizedBox(height: 24),
                            ],
                            const SizedBox(height: 16),
                            if (_isLoading)
                              CircularProgressIndicator(color: mainColor)
                            else ...[
                              ElevatedButton(
                                onPressed: _handleAuth,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  backgroundColor: mainColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  _isCreatingAccount
                                      ? (_signupStep == 0
                                          ? 'Next'
                                          : (_signupStep == 1 ? 'Verify' : context.t('create_account')))
                                      : context.t('login'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _isCreatingAccount && _signupStep > 0
                                    ? (_inviteToken != null ? _toggleMode : () => setState(() => _signupStep--))
                                    : _toggleMode,
                                child: Text(
                                  _isCreatingAccount
                                      ? (_signupStep > 0 ? 'Back' : context.t('back_to_login'))
                                      : context.t('create_new_account'),
                                  style: TextStyle(color: mainColor),
                                ),
                              ),                              if (!_isCreatingAccount) ...[
                                TextButton(
                                  onPressed: _toggleRecovery,
                                  child: Text(
                                    context.t('forgot_password'),
                                    style: TextStyle(color: mainColor),
                                  ),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const AboutPage(),
                                        ),
                                      ),
                                  child: Text(
                                    context.t('about'),
                                    style: TextStyle(color: mainColor),
                                  ),
                                ),
                              ],
                            ],
                          ] else ...[
                            Text(
                              effectiveStep == 0 ? context.t('restore_password') : 'Set Your Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: mainColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (effectiveStep == 0) ...[
                              TextField(
                                focusNode: _emailFocusNode,
                                controller: _emailController,
                                decoration: InputDecoration(
                                  labelText: context.t('email'),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.email),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: mainColor, width: 2),
                                  ),
                                ),
                                onSubmitted: (_) => _handleRecovery(),
                              ),
                            ],
                            const SizedBox(height: 12),
                            if (effectiveStep == 1) ...[
                              if (!_authService.isPasswordRecoveryFlow) ...[
                                TextField(
                                  controller: _codeController,
                                  decoration: InputDecoration(
                                    labelText: 'Reset Code',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.pin),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(color: mainColor, width: 2),
                                    ),
                                  ),
                                  onSubmitted: (_) => _handleRecovery(),
                                ),
                                const SizedBox(height: 12),
                              ],
                              TextField(
                                key: _passwordKey,
                                controller: _passwordController,
                                obscureText: true,
                                autofillHints: null,
                                decoration: InputDecoration(
                                  labelText: context.t('new_password'),
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.lock),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: mainColor, width: 2),
                                  ),
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
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: mainColor, width: 2),
                                  ),
                                ),
                                onSubmitted: (_) => _handleRecovery(),
                              ),
                            ],
                            const SizedBox(height: 24),
                            if (_isLoading)
                              CircularProgressIndicator(color: mainColor)
                            else ...[
                              ElevatedButton(
                                onPressed: _handleRecovery,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 50),
                                  backgroundColor: mainColor,
                                  foregroundColor: Colors.white,
                                ),
                                child: Text(
                                  effectiveStep == 0 ? 'Send Reset Link' : 'Update Password',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _toggleRecovery,
                                child: Text(
                                  context.t('back_to_login'),
                                  style: TextStyle(color: mainColor),
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                if (!kIsWeb)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        WindowControls(
                          onlyClose: true,
                          showSeparator: false,
                          color: mainColor,
                          iconSize: 28,
                          padding: false,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _authService.removeListener(_syncWithServiceState);
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
