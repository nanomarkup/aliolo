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

import 'package:aliolo/core/utils/logger.dart';

void main() async {
  try {
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

    runApp(const AlioloApp());
  } catch (e, stack) {
    print('CRITICAL MAIN ERROR: $e');
    print(stack);
  }
}

class AlioloApp extends StatefulWidget {
  const AlioloApp({super.key});

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
      await setupLocator();
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
                    const Icon(Icons.school, size: 80, color: Colors.orange),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Colors.orange),
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

class AlioloMainApp extends StatelessWidget {
  const AlioloMainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final translationService = context.watch<TranslationService>();
    final themeService = context.watch<ThemeService>();
    final authService = context.watch<AuthService>();

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeService.themeNotifier,
      builder: (context, currentMode, _) {
        final user = authService.currentUser;
        return MaterialApp(
          title: 'Aliolo',
          debugShowCheckedModeBanner: false,
          locale: translationService.currentLocale,
          themeMode: currentMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeService.primaryColor,
              surface: Colors.white,
              surfaceContainerHighest: const Color(0xFFF5F7FA),
            ),
            scaffoldBackgroundColor: const Color(0xFFF5F7FA),
            cardTheme: const CardThemeData(
              color: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 2,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: themeService.primaryColor,
              brightness: Brightness.dark,
              surface: const Color(0xFF1A1C1E),
              surfaceContainerHighest: const Color(0xFF0F1113),
            ),
            scaffoldBackgroundColor: const Color(0xFF0F1113),
            cardTheme: const CardThemeData(
              color: Color(0xFF1A1C1E),
              surfaceTintColor: Color(0xFF1A1C1E),
              elevation: 2,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          home: FutureBuilder<bool>(
            future: SharedPreferences.getInstance().then(
              (p) => p.getBool('has_seen_onboarding') ?? false,
            ),
            builder: (context, onboardingSnapshot) {
              if (onboardingSnapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final hasSeenOnboarding = onboardingSnapshot.data ?? false;

              if (!hasSeenOnboarding) {
                return const OnboardingPage();
              }

              return SelectionArea(
                child: user == null ? const LoginPage() : const SubjectPage(),
              );
            },
          ),
        );
      },
    );
  }
}
