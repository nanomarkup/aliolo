import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:media_kit/media_kit.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/learning_language_service.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';

import 'package:aliolo/core/utils/logger.dart';

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await AppLogger.init();
    MediaKit.ensureInitialized();

    if (!kIsWeb) {
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
                      context.t('initializing_aliolo'),
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
              value: getIt<LearningLanguageService>(),
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
            cardTheme: const CardTheme(
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
            cardTheme: const CardTheme(
              color: Color(0xFF1A1C1E),
              surfaceTintColor: Color(0xFF1A1C1E),
              elevation: 2,
            ),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          home: SelectionArea(
            child: user == null ? const LoginPage() : const SubjectPage(),
          ),
        );
      },
    );
  }
}
