import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';
import 'slides.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  double _dailyGoal = 30;

  late final Player _player1;
  late final VideoController _controller1;
  
  late final Player _player3;
  late final VideoController _controller3;
  
  late final Player _player4;
  late final VideoController _controller4;

  final Color primaryColor = const Color(0xFF1D4289);
  final Color bgColor = const Color(0xFFF1F5F9);

  @override
  void initState() {
    super.initState();
    _player1 = Player();
    _controller1 = VideoController(_player1);
    _player1.open(Media('asset:///assets/Slide1_v4.webm'));
    _player1.setPlaylistMode(PlaylistMode.loop);

    _player3 = Player();
    _controller3 = VideoController(_player3);
    _player3.open(Media('asset:///assets/Slide3_v1.webm'));
    _player3.setPlaylistMode(PlaylistMode.loop);

    _player4 = Player();
    _controller4 = VideoController(_player4);
    _player4.open(Media('asset:///assets/Slide4_v1.mp4'));
    _player4.setPlaylistMode(PlaylistMode.loop);
  }

  @override
  void dispose() {
    _player1.dispose();
    _player3.dispose();
    _player4.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    
    final authService = getIt<AuthService>();
    if (authService.currentUser != null) {
      await authService.updateNextDailyGoal(_dailyGoal.toInt());
    }

    if (!mounted) return;

    Widget nextPath;
    if (authService.currentUser != null) {
      nextPath = const SubjectPage();
    } else {
      nextPath = const LoginPage();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextPath,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() => _currentPage = page);
            },
            children: [
              // Slide 1: Hook
              OnboardingSlide(
                visual: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Video(
                        controller: _controller1,
                        controls: NoVideoControls,
                        fill: Colors.transparent,
                      ),
                    ),
                  ),
                ),
                title: "Welcome to Aliolo",
                description: "Learn Visually. Master Permanently. Your visual learning companion powered by SM-2 science.",
              ),
              // Slide 2: Smart Learning
              const OnboardingSlide(
                visual: SizedBox.shrink(),
                title: "Interactive Cards",
                description: "Multimedia cards adapt to your pace. Swipe to Learn, Tap to Test.",
              ),
              // Slide 3: Create & Share (New)
              OnboardingSlide(
                visual: Icon(Icons.groups, size: 120, color: primaryColor),
                title: "Create & Share",
                description: "Build your own subjects or master decks shared by the Aliolo community.",
              ),
              // Slide 4: Goal Setting
              OnboardingSlide(
                visual: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Video(
                      controller: _controller3,
                      controls: NoVideoControls,
                      fill: Colors.transparent,
                    ),
                  ),
                ),
                title: "Build Your Streak",
                description: "Consistency is key! Set your Daily Goal and rise through the ranks—both globally and against your friends.",
              ),
              // Slide 5: Sync
              OnboardingSlide(
                visual: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Video(
                      controller: _controller4,
                      controls: NoVideoControls,
                      fill: Colors.transparent,
                    ),
                  ),
                ),
                title: "Master Anywhere",
                description: "Your library stays in sync across all your devices. We’ll only nudge you when it’s time to protect your streak.",
              ),
            ],
          ),
          // Top Overlay: Skip
          if (_currentPage < 4)
            Positioned(
              top: 48,
              right: 20,
              child: TextButton(
                onPressed: _finishOnboarding,
                child: Text(
                  context.t('onboarding_skip'),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 16),
                ),
              ),
            ),
          // Bottom Overlay: Dots and Button
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentPage == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index 
                            ? primaryColor 
                            : primaryColor.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: ElevatedButton(
                      onPressed: () {
                        if (_currentPage == 4) {
                          _finishOnboarding();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == 4 ? "Get Started" : "Next",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
