import 'package:flutter/material.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';

class CheckoutIdentityPage extends StatefulWidget {
  const CheckoutIdentityPage({super.key});

  @override
  State<CheckoutIdentityPage> createState() => _CheckoutIdentityPageState();
}

class _CheckoutIdentityPageState extends State<CheckoutIdentityPage> {
  final _authService = getIt<AuthService>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  int _step = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _requestOtp() async {
    final email = _emailController.text.trim().toLowerCase();
    if (!_authService.isValidEmail(email)) {
      _showMessage('Enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);
    final success = await _authService.requestOtp(email);
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      setState(() => _step = 1);
      _showMessage('Verification code sent to $email');
      return;
    }

    final message =
        _authService.lastErrorMessage ?? 'Failed to send verification code.';
    _showMessage(message);
    if (message.toLowerCase().contains('already exists')) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  Future<void> _verifyAndContinue() async {
    final email = _emailController.text.trim().toLowerCase();
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showMessage('Enter the 6-digit verification code.');
      return;
    }

    setState(() => _isLoading = true);
    final verified = await _authService.verifyOtp(email, code);
    if (!verified) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(
        _authService.lastErrorMessage ?? 'Invalid verification code.',
      );
      return;
    }

    setState(() {
      _isLoading = false;
      _step = 2;
    });
  }

  Future<void> _createAccountAndContinue() async {
    final email = _emailController.text.trim().toLowerCase();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (username.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Fill in all fields.');
      return;
    }
    if (password != confirmPassword) {
      _showMessage("Passwords don't match.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _authService.createUser(username, email, password);
    } catch (_) {}

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (_authService.currentUser?.serverId != null) {
      Navigator.pop(context, true);
      return;
    }

    final message =
        _authService.lastErrorMessage ?? 'Could not create your account.';
    _showMessage(message);
    if (message.toLowerCase().contains('already exists') ||
        message.toLowerCase().contains('log in')) {
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        _step == 0
            ? context.t('create_account_to_continue')
            : _step == 1
            ? context.t('verify_your_email')
            : context.t('finish_account_setup');
    final subtitle =
        _step == 0
            ? context.t('checkout_email_before_payment_desc')
            : _step == 1
            ? context.t('checkout_verification_desc')
            : context.t('checkout_finish_account_desc');

    return Scaffold(
      appBar: AppBar(title: Text(context.t('continue_to_checkout'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey[700], fontSize: 15),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: _emailController,
                  enabled: !_isLoading && _step == 0,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: context.t('email'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_step == 1) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _codeController,
                    enabled: !_isLoading,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: InputDecoration(
                      labelText: context.t('verification_code'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_step == 2) ...[
                  TextField(
                    controller: _usernameController,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: context.t('username'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    enabled: !_isLoading,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.t('password'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    enabled: !_isLoading,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.t('confirm_password'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed:
                        _step == 0
                            ? _requestOtp
                            : _step == 1
                            ? _verifyAndContinue
                            : _createAccountAndContinue,
                    child: Text(
                      _step == 0
                          ? 'Send verification code'
                          : _step == 1
                          ? 'Continue'
                          : 'Create account and continue to payment',
                    ),
                  ),
                const SizedBox(height: 12),
                if (_step > 0)
                  TextButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                              setState(() {
                                if (_step == 2) {
                                  _step = 1;
                                  _usernameController.clear();
                                  _passwordController.clear();
                                  _confirmPasswordController.clear();
                                } else {
                                  _step = 0;
                                  _codeController.clear();
                                }
                              });
                            },
                    child: Text(
                      _step == 2
                          ? 'Back to verification'
                          : 'Use a different email',
                    ),
                  ),
                TextButton(
                  onPressed:
                      _isLoading
                          ? null
                          : () async {
                            await Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            );
                          },
                  child: Text(context.t('log_in_instead')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
