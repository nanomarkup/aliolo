import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingData> _screens = [
    OnboardingData(
      icon: Icons.auto_awesome,
      titleKey: 'onboarding_1_title',
      descKey: 'onboarding_1_desc',
    ),
    OnboardingData(
      icon: Icons.psychology,
      titleKey: 'onboarding_2_title',
      descKey: 'onboarding_2_desc',
    ),
    OnboardingData(
      icon: Icons.emoji_events,
      titleKey: 'onboarding_3_title',
      descKey: 'onboarding_3_desc',
    ),
    OnboardingData(
      icon: Icons.groups,
      titleKey: 'onboarding_4_title',
      descKey: 'onboarding_4_desc',
    ),
    OnboardingData(
      icon: Icons.sync,
      titleKey: 'onboarding_5_title',
      descKey: 'onboarding_5_desc',
    ),
    OnboardingData(
      icon: Icons.add_circle_outline,
      titleKey: 'onboarding_6_title',
      descKey: 'onboarding_6_desc',
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        final authService = getIt<AuthService>();
        if (authService.currentUser != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const SubjectPage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeService = getIt<ThemeService>();

    return ListenableBuilder(
      listenable: themeService,
      builder: (context, _) {
        final mainColor = themeService.getSystemColor(Brightness.light);
        const isDark = false; // Forced light mode

        return Theme(
          data: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: mainColor,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF1F5F9),
            fontFamily: 'Roboto',
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Stack(
                  children: [
                    PageView.builder(
                      controller: _pageController,
                      itemCount: _screens.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final screen = _screens[index];
                        return Center(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    screen.icon,
                                    size: 120,
                                    color: mainColor,
                                  ),
                                  const SizedBox(height: 40),
                                  Text(
                                    context.t(screen.titleKey),
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: mainColor,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    context.t(screen.descKey),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      height: 1.5,
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Top Skip Button
                    Positioned(
                      top: 48,
                      right: 20,
                      child: TextButton(
                        onPressed: _completeOnboarding,
                        child: Text(
                          context.t('onboarding_skip'),
                          style: const TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    ),
                    // Bottom Navigation
                    Positioned(
                      bottom: 60,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          // Indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(
                              _screens.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                height: 8,
                                width: _currentPage == index ? 24 : 8,
                                decoration: BoxDecoration(
                                  color:
                                      _currentPage == index
                                          ? mainColor
                                          : mainColor.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Next/Get Started Button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: ElevatedButton(
                                onPressed: () {
                                  if (_currentPage == _screens.length - 1) {
                                    _completeOnboarding();
                                  } else {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: mainColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  _currentPage == _screens.length - 1
                                      ? context.t('onboarding_get_started')
                                      : context.t('onboarding_next'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class OnboardingData {
  final IconData icon;
  final String titleKey;
  final String descKey;

  OnboardingData({
    required this.icon,
    required this.titleKey,
    required this.descKey,
  });
}
