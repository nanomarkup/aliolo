import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/theme/aliolo_theme.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/onboarding/presentation/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:aliolo/core/utils/file_stub.dart'
    if (dart.library.html) 'dart:html'
    as html;

import 'package:aliolo/data/services/friendship_service.dart';
import 'package:aliolo/features/auth/presentation/pages/manage_friends_page.dart';

import 'package:aliolo/core/utils/logger.dart';

void main() async {
  try {
    String? initialUrl;
    String? inviteToken;
    if (kIsWeb) {
      initialUrl = html.window.location.href;
      final uri = Uri.parse(initialUrl);
      inviteToken = uri.queryParameters['invite'];
    }
    usePathUrlStrategy();
    WidgetsFlutterBinding.ensureInitialized();
    await AppLogger.init();

    LicenseRegistry.addLicense(() {
      return Stream<LicenseEntry>.fromIterable([
        const LicenseEntryWithLineBreaks(
          ['Aliolo Commercial License'],
          """
Aliolo Commercial Software License

Copyright (c) 2026 Aliolo Team. All Rights Reserved.

This software and all associated files, source code, and assets are proprietary
to the Aliolo Team and are licensed, not sold.

This license governs the software distribution itself. Access to premium
features, services, or other paid functionality may require a separate,
valid subscription agreement.

If a subscription ends, premium access may be suspended, limited, or removed
in accordance with the applicable subscription terms. Free features, if any,
remain subject to the same license and product terms.

Unauthorized copying, modification, distribution, or decompilation of this
software is strictly prohibited.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY.
""",
        ),
      ]);
    });

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows)) {
      MediaKit.ensureInitialized();
    }

    if (!kIsWeb) {
      if (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows) {
        await windowManager.ensureInitialized();
        windowManager.waitUntilReadyToShow(
          const WindowOptions(
            size: Size(1024, 1024),
            center: true,
            title: 'Aliolo',
          ),
          () async {
            await windowManager.show();
            await windowManager.focus();
          },
        );
      }
    }

    runApp(AlioloApp(initialUrl: initialUrl, inviteToken: inviteToken));
  } catch (e, stack) {
    print('CRITICAL MAIN ERROR: $e');
    print(stack);
  }
}

class AlioloApp extends StatefulWidget {
  final String? initialUrl;
  final String? inviteToken;
  const AlioloApp({super.key, this.initialUrl, this.inviteToken});

  @override
  State<AlioloApp> createState() => _AlioloAppState();
}

class _AlioloAppState extends State<AlioloApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _doInit();
  }

  Future<void> _doInit() async {
    try {
      await setupLocator(
        initialUrl: widget.initialUrl,
        inviteToken: widget.inviteToken,
      );
      await getIt<SubscriptionService>().init();
    } catch (e, stack) {
      print('Initialization failed: $e');
      print(stack);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.red[900],
              body: SelectionArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          context.t('fatal_startup_error'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          snapshot.error.toString(),
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed:
                              () => setState(() {
                                _initFuture = _doInit();
                              }),
                          child: Text(context.t('retry')),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.school,
                      size: 80,
                      color: Color(0xFF1D4289),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Color(0xFF1D4289)),
                    const SizedBox(height: 16),
                    Text(
                      context.t('Initializing Aliolo'),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: getIt<AuthService>()),
            ChangeNotifierProvider.value(value: getIt<TranslationService>()),
            ChangeNotifierProvider.value(
              value: getIt<TestingLanguageService>(),
            ),
            ChangeNotifierProvider.value(value: getIt<SubscriptionService>()),
            ChangeNotifierProvider.value(value: getIt<CardService>()),
            ListenableProvider.value(value: getIt<ThemeService>()),
          ],
          child: const AlioloMainApp(),
        );
      },
    );
  }
}

class InstantPageTransitionsBuilder extends PageTransitionsBuilder {
  const InstantPageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class AlioloMainApp extends StatefulWidget {
  const AlioloMainApp({super.key});

  @override
  State<AlioloMainApp> createState() => _AlioloMainAppState();
}

class _AlioloMainAppState extends State<AlioloMainApp> {
  late Future<bool> _onboardingFuture;
  Future<bool>? _friendshipFuture;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _onboardingFuture = _loadOnboardingStatus();
  }

  Future<bool> _loadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_seen_onboarding') ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final translationService = context.watch<TranslationService>();
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    // Refresh friendship future if user changes
    if (user?.serverId != _lastUserId) {
      _lastUserId = user?.serverId;
      if (_lastUserId != null) {
        _friendshipFuture = FriendshipService().hasPendingRequests();
      } else {
        _friendshipFuture = null;
      }
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeService.themeNotifier,
      builder: (context, currentMode, _) {
        final brightness =
            currentMode == ThemeMode.system
                ? View.of(context).platformDispatcher.platformBrightness
                : (currentMode == ThemeMode.dark
                    ? Brightness.dark
                    : Brightness.light);

        return MaterialApp(
          title: 'Aliolo',
          debugShowCheckedModeBanner: false,
          locale: translationService.currentLocale,
          themeMode: currentMode,
          theme: AlioloTheme.build(
            seedColor: themeService.getAdjustedPrimary(brightness: brightness),
            brightness: brightness,
          ),
          darkTheme: AlioloTheme.build(
            seedColor: themeService.getAdjustedPrimary(),
            brightness: Brightness.dark,
          ),
          home: FutureBuilder<bool>(
            future: _onboardingFuture,
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final hasSeenOnboarding = onboardingSnapshot.data ?? false;

              if (!hasSeenOnboarding) {
                return const OnboardingScreen();
              }

              if (authService.isPasswordRecoveryFlow ||
                  authService.isInviteFlow) {
                return const LoginPage();
              }

              if (user == null) {
                return const SelectionArea(child: LoginPage());
              }

              return FutureBuilder<bool>(
                future: _friendshipFuture ?? Future.value(false),
                builder: (context, friendshipSnapshot) {
                  if (friendshipSnapshot.connectionState !=
                      ConnectionState.done) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final hasPending = friendshipSnapshot.data ?? false;
                  return SelectionArea(
                    child:
                        hasPending
                            ? const ManageFriendsPage()
                            : const SubjectPage(),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
