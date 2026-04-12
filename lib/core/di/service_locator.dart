import 'package:get_it/get_it.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/testing_language_service.dart';
import 'package:aliolo/data/services/sound_service.dart';
import 'package:aliolo/data/services/math_service.dart';
import 'package:aliolo/data/services/progress_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/data/services/feedback_service.dart';
import 'package:aliolo/data/services/discovery_engine.dart';
import 'package:aliolo/data/services/filter_service.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';


final getIt = GetIt.instance;

Future<void> setupLocator({String? initialUrl}) async {
  try {
    // 0. Network
    getIt.registerSingleton<CloudflareHttpClient>(CloudflareHttpClient());

    // 1. Register base singleton services
    getIt.registerSingleton<CardService>(CardService());
    getIt.registerSingleton<AuthService>(AuthService());
    getIt.registerSingleton<TranslationService>(TranslationService());
    getIt.registerSingleton<TestingLanguageService>(TestingLanguageService());
    getIt.registerSingleton<SoundService>(SoundService());
    getIt.registerSingleton<FeedbackService>(FeedbackService());
    getIt.registerSingleton<DiscoveryEngine>(DiscoveryEngine());
    getIt.registerSingleton<FilterService>(FilterService());

    // 2. Initialize critical services in order
    await getIt<CardService>().init().catchError(
      (e) => print('CardService init error: $e'),
    );

    await getIt<AuthService>().init(manualUrl: initialUrl).catchError(
      (e) => print('AuthService init error: $e'),
    );

    await getIt<FilterService>().init().catchError(
      (e) => print('FilterService init error: $e'),
    );

    print('Initializing TranslationService...');
    await getIt<TranslationService>().init().catchError(
      (e) => print('TranslationService init error: $e'),
    );

    print('Initializing TestingLanguageService...');
    await getIt<TestingLanguageService>().init().catchError(
      (e) => print('TestingLanguageService init error: $e'),
    );

    print('Initializing SoundService...');
    await getIt<SoundService>().init().catchError(
      (e) => print('SoundService init error: $e'),
    );

    // 3. Register remaining services
    getIt.registerLazySingleton<ThemeService>(() => ThemeService());
    getIt.registerLazySingleton<MathService>(() => MathService());
    getIt.registerLazySingleton<ProgressService>(() => ProgressService());
    getIt.registerLazySingleton<SubscriptionService>(() => SubscriptionService());

    print('All services initialized in remote-only mode.');
  } catch (e, stack) {
    print('FATAL setupLocator error: $e');
    print(stack);
    rethrow;
  }
}
