import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:aliolo/core/utils/file_stub.dart' if (dart.library.html) 'dart:html' as html;

import 'package:aliolo/data/services/friendship_service.dart';
import 'package:aliolo/features/auth/presentation/pages/manage_friends_page.dart';

import 'package:aliolo/core/utils/logger.dart';

void main() async {
  try {
    String? initialUrl;
    if (kIsWeb) {
      initialUrl = html.window.location.href;
    }
    usePathUrlStrategy();
    WidgetsFlutterBinding.ensureInitialized();
    await AppLogger.init();

    // Initialize Supabase
    const String supabaseUrl = 'https://mltdjjszycfmokwqsqxm.supabase.co';
    const String supabaseKey = 'sb_publishable_DCMw0z92Lr2nzC83sOQJXw_G1fYdEb3';

    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);

    LicenseRegistry.addLicense(() {
      return Stream<LicenseEntry>.fromIterable([
        const LicenseEntryWithLineBreaks(
          ['Aliolo'],
          """
Aliolo - Commercial License

Copyright (c) 2026 Aliolo Team. All Rights Reserved.

This software and all associated files, source code, and assets are the sole
property of the Aliolo Team. Unauthorized copying, modification, distribution,
or decompilation of this software is strictly prohibited.

Use of this software is subject to a valid, active subscription agreement.
Failure to maintain a subscription will result in the termination of access to
the software's features and services.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY.
""",
        ),
      ]);
    });

    MediaKit.ensureInitialized();

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

    runApp(AlioloApp(initialUrl: initialUrl));
  } catch (e, stack) {
    print('CRITICAL MAIN ERROR: $e');
    print(stack);
  }
}

class AlioloApp extends StatefulWidget {
  final String? initialUrl;
  const AlioloApp({super.key, this.initialUrl});

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
      await setupLocator(initialUrl: widget.initialUrl);
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
                    const Icon(Icons.school, size: 80, color: Color(0xFF1D4289)),
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
        final brightness = currentMode == ThemeMode.system
            ? View.of(context).platformDispatcher.platformBrightness
            : (currentMode == ThemeMode.dark ? Brightness.dark : Brightness.light);

        return MaterialApp(
          title: 'Aliolo',
          debugShowCheckedModeBanner: false,
          locale: translationService.currentLocale,
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeService.getAdjustedPrimary(brightness: brightness),
              surface: Colors.white,
              surfaceContainerHighest: const Color(
                0xFFE2E8F0,
              ), // Subtle divider/dropdown color
            ),
            scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Slate-grey background
            cardTheme: CardThemeData(
              color: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
            ),
            dividerTheme: DividerThemeData(
              color: Colors.black.withValues(alpha: 0.05),
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: InstantPageTransitionsBuilder(),
                TargetPlatform.iOS: InstantPageTransitionsBuilder(),
                TargetPlatform.linux: InstantPageTransitionsBuilder(),
                TargetPlatform.macOS: InstantPageTransitionsBuilder(),
                TargetPlatform.windows: InstantPageTransitionsBuilder(),
              },
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeService.getAdjustedPrimary(),
              brightness: Brightness.dark,
              surface: const Color(0xFF1E293B), // Deep slate surface
              surfaceContainerHighest: const Color(0xFF334155),
              shadow: Colors.transparent,
            ),
            shadowColor: Colors.transparent,
            scaffoldBackgroundColor: const Color(
              0xFF0F172A,
            ), // Very deep navy/slate background
            cardTheme: CardThemeData(
              color: const Color(0xFF1E293B),
              surfaceTintColor: const Color(0xFF1E293B),
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
            ),
            appBarTheme: const AppBarTheme(
              elevation: 0,
              scrolledUnderElevation: 0,
              shadowColor: Colors.transparent,
            ),
            dividerTheme: DividerThemeData(
              color: Colors.white.withValues(alpha: 0.05),
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
            pageTransitionsTheme: const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: InstantPageTransitionsBuilder(),
                TargetPlatform.iOS: InstantPageTransitionsBuilder(),
                TargetPlatform.linux: InstantPageTransitionsBuilder(),
                TargetPlatform.macOS: InstantPageTransitionsBuilder(),
                TargetPlatform.windows: InstantPageTransitionsBuilder(),
              },
            ),
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

              print('--- DEBUG: MAIN APP HOME BUILD ---');
              print(
                'AuthService isPasswordRecoveryFlow: ${authService.isPasswordRecoveryFlow}',
              );
              print('CurrentUser: ${user?.email}');
              print('HasSeenOnboarding: $hasSeenOnboarding');

              if (!hasSeenOnboarding) {
                return const OnboardingPage();
              }

              if (authService.isPasswordRecoveryFlow) {
                print('MainApp: Showing LoginPage due to recovery flow');
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
