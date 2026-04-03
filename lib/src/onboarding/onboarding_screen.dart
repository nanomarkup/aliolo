import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/models/pillar_model.dart';
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
  String? _selectedAge;
  int? _selectedPillarId;

  late final Player _player1;
  late final VideoController _controller1;

  final Color primaryColor = const Color(0xFF1D4289);
  final Color bgColor = const Color(0xFFF1F5F9);

  final List<String> ageOptions = [
    'Under 14',
    '15 - 18',
    '19 - 25',
    '26 - 35',
    '36 - 50',
    'Over 50',
  ];

  @override
  void initState() {
    super.initState();
    _player1 = Player();
    _controller1 = VideoController(_player1);
    _player1.open(Media('asset:///assets/Slide1_v1.webm'));
    _player1.setPlaylistMode(PlaylistMode.none);
  }

  void _handlePageChange(int page) {
    setState(() => _currentPage = page);
    
    // Manage playback based on slide index
    if (page == 0) {
      _player1.seek(Duration.zero);
      _player1.play();
    } else {
      _player1.pause();
    }
  }

  @override
  void dispose() {
    _player1.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (_selectedAge != null) {
      await prefs.setString('user_age_range', _selectedAge!);
    }
    
    final authService = getIt<AuthService>();
    if (authService.currentUser != null) {
      await authService.updateNextDailyGoal(_dailyGoal.toInt());
      if (_selectedPillarId != null) {
        await authService.updateMainColorFromPillar(_selectedPillarId!);
      }
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
    final String displayLang = getIt<TranslationService>().currentLocale.languageCode;
    
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: _handlePageChange,
            children: [
              // Slide 1: Hook
              OnboardingSlide(
                visual: ClipRRect(
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
                title: "Welcome to Aliolo",
                description: "Learn Visually. Master Permanently. Your visual learning companion powered by SM-2 science.",
              ),
              // Slide 2: Age Selection
              OnboardingSlide(
                visual: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 2.5,
                      physics: const NeverScrollableScrollPhysics(),
                      children: ageOptions.map((age) {
                        final bool isSelected = _selectedAge == age;
                        return InkWell(
                          onTap: () => setState(() => _selectedAge = age),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? primaryColor : Colors.black.withValues(alpha: 0.1),
                              ),
                              boxShadow: [
                                if (isSelected)
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Text(
                              age,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                title: "How old are you?",
                description: "This helps us personalize your learning experience and recommend the right subjects.",
              ),
              // Slide 3: Pillar Selection
              OnboardingSlide(
                visual: pillars.isEmpty 
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.8,
                        physics: const NeverScrollableScrollPhysics(),
                        children: pillars.map((pillar) {
                          final bool isSelected = _selectedPillarId == pillar.id;
                          return _OnboardingPillarTile(
                            pillar: pillar,
                            isSelected: isSelected,
                            displayLang: displayLang,
                            onTap: () {
                              setState(() => _selectedPillarId = pillar.id);
                              Future.delayed(const Duration(milliseconds: 300), () {
                                if (mounted) {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                title: "What do you want to master?",
                description: "Select your primary interest to customize your initial dashboard.",
              ),
              // Slide 4: Create & Share (New)
              OnboardingSlide(
                visual: Icon(Icons.groups, size: 120, color: primaryColor),
                title: "Create & Share",
                description: "Build your own deck or dive into cards shared by Aliolo learners worldwide.\n\nLearn at your pace, then test yourself when you're ready.",
              ),
              // Slide 5: Sync
              OnboardingSlide(
                visual: Icon(Icons.cloud_sync_outlined, size: 120, color: primaryColor),
                title: "Master Anywhere",
                description: "Your library stays in sync across all your devices. We’ll only nudge you when it’s time to protect your streak.",
              ),
              // Slide 6: Social Proof
              OnboardingSlide(
                visual: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.format_quote, color: Color(0xFF1D4289), size: 40),
                              const SizedBox(height: 16),
                              const Text(
                                "\"Aliolo changed the way I learn languages. The visual cards and spaced repetition make everything stick!\"",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    height: 40,
                                    child: Stack(
                                      children: [
                                        Positioned(left: 0, child: _buildUserAvatar(Colors.blue[100]!, Icons.person)),
                                        Positioned(left: 20, child: _buildUserAvatar(Colors.green[100]!, Icons.person_outline)),
                                        Positioned(left: 40, child: _buildUserAvatar(Colors.orange[100]!, Icons.face)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Text(
                                      "Joined by 10,000+ learners",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "5/5",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D4289),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: List.generate(5, (index) => const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 28,
                              )),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Average learner rating",
                          style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ),
                title: "Join the Community",
                description: "Start your journey today and master anything you set your mind to.",
              ),
              // Slide 7: Paywall (Placeholder)
              OnboardingSlide(
                visual: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.workspace_premium, color: Colors.amber, size: 80),
                      const SizedBox(height: 24),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          children: [
                            _buildSubscriptionOption("Weekly Access", r"$2.99", "Best for quick goals", originalPrice: r"$5.98"),
                            const SizedBox(height: 12),
                            _buildSubscriptionOption("Monthly Access", r"$8.99", "Most popular choice", originalPrice: r"$17.98", isSelected: true),
                            const SizedBox(height: 12),
                            _buildSubscriptionOption("Yearly Access", r"$80.99", "Save 33% per month", originalPrice: r"$161.98"),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                title: "Unlock Full Access",
                description: "Get unlimited cards, AI-powered insights, and sync across all your devices.",
              ),
            ],
          ),
          // Top Overlay: Skip
          if (_currentPage < 6)
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
                  children: List.generate(7, (index) {
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
                        if (_currentPage == 6) {
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
                        _currentPage == 6 ? "Get Started" : "Next",
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

  Widget _buildSubscriptionOption(String title, String price, String sub, {bool isSelected = false, String? originalPrice}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? primaryColor : Colors.black.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(sub, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (originalPrice != null)
                Text(
                  originalPrice,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              Text(
                price,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF1D4289),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(Color color, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: primaryColor.withValues(alpha: 0.5), size: 20),
    );
  }
}

class _OnboardingPillarTile extends StatelessWidget {
  final Pillar pillar;
  final bool isSelected;
  final String displayLang;
  final VoidCallback onTap;

  const _OnboardingPillarTile({
    required this.pillar,
    required this.isSelected,
    required this.displayLang,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pillarColor = pillar.getColor(getIt<ThemeService>().isDarkMode);
    
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: isSelected 
          ? BorderSide(color: Colors.white.withValues(alpha: 0.8), width: 3)
          : BorderSide.none,
      ),
      elevation: isSelected ? 8 : 4,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                pillarColor,
                pillarColor.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -10,
                bottom: -10,
                child: Icon(
                  pillar.getIconData(),
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(pillar.getIconData(), color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pillar.getTranslatedName(displayLang),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: Text(
                        pillar.getTranslatedDescription(displayLang),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.check, size: 16, color: pillarColor),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
