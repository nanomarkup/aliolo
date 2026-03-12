import 'package:get_it/get_it.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/subject_service.dart';
import 'package:aliolo/data/services/learning_language_service.dart';
import 'package:aliolo/data/services/sound_service.dart';
import 'package:aliolo/data/services/math_service.dart';
import 'package:aliolo/data/services/progress_service.dart';

final getIt = GetIt.instance;

Future<void> setupLocator() async {
  try {
    // 1. Register base singleton services
    getIt.registerSingleton<CardService>(CardService());
    getIt.registerSingleton<AuthService>(AuthService());
    getIt.registerSingleton<TranslationService>(TranslationService());
    getIt.registerSingleton<LearningLanguageService>(LearningLanguageService());
    getIt.registerSingleton<SoundService>(SoundService());

    // 2. Initialize critical services in order
    print('Initializing CardService...');
    await getIt<CardService>().init().catchError(
      (e) => print('CardService init error: $e'),
    );

    print('Initializing AuthService...');
    await getIt<AuthService>().init().catchError(
      (e) => print('AuthService init error: $e'),
    );

    print('Initializing TranslationService...');
    await getIt<TranslationService>().init().catchError(
      (e) => print('TranslationService init error: $e'),
    );

    print('Initializing LearningLanguageService...');
    await getIt<LearningLanguageService>().init().catchError(
      (e) => print('LearningLanguageService init error: $e'),
    );

    print('Initializing SoundService...');
    await getIt<SoundService>().init().catchError(
      (e) => print('SoundService init error: $e'),
    );

    // 3. Register remaining services
    getIt.registerLazySingleton<ThemeService>(() => ThemeService());
    getIt.registerLazySingleton<SubjectService>(() => SubjectService());
    getIt.registerLazySingleton<MathService>(() => MathService());
    getIt.registerLazySingleton<ProgressService>(() => ProgressService());

    print('All services initialized in remote-only mode.');
  } catch (e, stack) {
    print('FATAL setupLocator error: $e');
    print(stack);
    rethrow;
  }
}
