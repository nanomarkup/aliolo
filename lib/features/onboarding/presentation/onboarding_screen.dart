import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:uuid/uuid.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';
import 'package:aliolo/features/settings/presentation/pages/billing_page.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'slides.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final String _sessionId = const Uuid().v4();
  final GlobalKey _featuresKey = GlobalKey();
  final _cfClient = getIt<CloudflareHttpClient>();
  
  int _currentPage = 0;
  double _dailyGoal = 30;
  String? _selectedAge;
  int? _selectedPillarId;
  int _selectedOptionIndex = 1; // Monthly by default
  bool _showFeatures = false;

  late final Player _player1;
  late final VideoController _controller1;

  final Color primaryColor = const Color(0xFF1D4289);
  final Color bgColor = const Color(0xFFF1F5F9);

  final List<String> ageOptions = [
    'age_under_14',
    'age_15_18',
    'age_19_25',
    'age_26_35',
    'age_36_50',
    'age_over_50',
  ];

  @override
  void initState() {
    super.initState();
    _initAnalytics();
    _player1 = Player();
    _controller1 = VideoController(_player1);
    _player1.open(Media('asset:///assets/Slide1_v7.mp4'));
    _player1.setPlaylistMode(PlaylistMode.none);
  }

  Future<void> _initAnalytics() async {
    try {
      await _cfClient.client.post('/api/analytics/onboarding', data: {
        'session_id': _sessionId,
      });
    } catch (e) {
      debugPrint('Error initializing onboarding analytics: $e');
    }
  }

  Future<void> _updateAnalytics({String? ageRange, int? pillarId, int? lastSlideIndex}) async {
    try {
      final updates = <String, dynamic>{
        'session_id': _sessionId,
      };
      if (ageRange != null) updates['age_range'] = ageRange;
      if (pillarId != null) updates['pillar_id'] = pillarId;
      if (lastSlideIndex != null) updates['last_slide_index'] = lastSlideIndex;
      
      await _cfClient.client.post('/api/analytics/onboarding', data: updates);
    } catch (e) {
      debugPrint('Error updating onboarding analytics: $e');
    }
  }

  void _handlePageChange(int page) {
    setState(() {
      _currentPage = page;
      if (page != 6) _showFeatures = false;
    });
    
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

  Future<void> _finishOnboarding({bool skipped = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    
    await _updateAnalytics(lastSlideIndex: _currentPage);

    if (_selectedAge != null) {
      await prefs.setString('user_age_range', _selectedAge!);
    }
    
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

  void _navigateToBilling(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => BillingPage(selectedIndex: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayLang = getIt<TranslationService>().currentLocale.languageCode;
    final subService = context.watch<SubscriptionService>();
    context.watch<CardService>(); // Keep watching for updates
    // Use the global pillars list from pillar_model.dart

    final List<Map<String, dynamic>> features = [
      {'name': context.t('feature_learn_all'), 'free': true},
      {'name': context.t('feature_community_access'), 'free': true},
      {'name': context.t('feature_spaced_repetition'), 'free': true},
      {'name': context.t('feature_favorites'), 'free': true},
      {'name': context.t('feature_friends'), 'free': true},
      {'name': context.t('feature_feedback'), 'free': true},
      {'name': context.t('feature_creation'), 'free': false},
      {'name': context.t('feature_testing'), 'free': false},
      {'name': context.t('feature_autoplay'), 'free': false},
      {'name': context.t('feature_customize'), 'free': false},
      {'name': context.t('feature_private_mode'), 'free': false},
    ];
    
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
                useFixedHeader: false,
                invertContent: true,
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
                title: context.t('onboarding_1_title'),
                description: context.t('onboarding_1_desc'),
              ),
              // Slide 2: Age Selection
              OnboardingSlide(
                useFixedHeader: false,
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
                      children: ageOptions.map((ageKey) {
                        final bool isSelected = _selectedAge == ageKey;
                        return InkWell(
                          onTap: () {
                            setState(() => _selectedAge = ageKey);
                            _updateAnalytics(ageRange: ageKey);
                            Future.delayed(const Duration(milliseconds: 300), () {
                              if (mounted) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? Colors.white.withValues(alpha: 0.8) : Colors.black.withValues(alpha: 0.05),
                                width: isSelected ? 3 : 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                                if (isSelected)
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                              ],
                            ),
                            child: Text(
                              context.t(ageKey),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                title: context.t('onboarding_2_title'),
                description: context.t('onboarding_2_desc'),
              ),
              // Slide 3: Pillar Selection
              OnboardingSlide(
                useFixedHeader: false,
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
                              _updateAnalytics(pillarId: pillar.id);
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
                title: context.t('onboarding_3_title'),
                description: context.t('onboarding_3_desc'),
              ),
              // Slide 4: Create & Share
              OnboardingSlide(
                useFixedHeader: false,
                visual: Icon(Icons.groups, size: 120, color: primaryColor),
                title: context.t('onboarding_4_title'),
                description: context.t('onboarding_4_desc'),
              ),
              // Slide 5: Sync
              OnboardingSlide(
                useFixedHeader: false,
                visual: Icon(Icons.cloud_sync_outlined, size: 120, color: primaryColor),
                title: context.t('onboarding_5_title'),
                description: context.t('onboarding_5_desc'),
              ),
              // Slide 6: Social Proof
              OnboardingSlide(
                useFixedHeader: false,
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
                              Text(
                                context.t('onboarding_7_quote'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black87,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
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
                        const SizedBox(height: 12),
                        Text(
                          context.t('onboarding_7_joined'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "4.8/5",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1D4289),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Row(
                              children: [
                                ...List.generate(4, (index) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 28,
                                )),
                                const Icon(Icons.star_half, color: Colors.amber, size: 28),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                title: context.t('onboarding_6_title'),
                description: context.t('onboarding_6_desc'),
              ),
              // Slide 7: Paywall
              OnboardingSlide(
                useFixedHeader: false,
                customBottomOffset: 104,
                visual: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.workspace_premium, color: Colors.amber, size: 80),
                        const SizedBox(height: 24),
                        if (subService.isPremium)
                          _buildPremiumSuccess(primaryColor)
                        else ...[
                          _buildSubscriptionOption(0, context.t('plan_weekly'), r"$2.99", context.t('plan_weekly_desc'), originalPrice: r"$5.98"),
                          const SizedBox(height: 12),
                          _buildSubscriptionOption(
                            1, context.t('plan_monthly'), r"$8.99", context.t('plan_monthly_desc'), 
                            originalPrice: r"$17.98", extraInfo: context.t('price_per_week', args: {'price': r'$2.25'})
                          ),
                          const SizedBox(height: 12),
                          _buildSubscriptionOption(
                            2, context.t('plan_yearly'), r"$80.99", context.t('plan_yearly_desc'), 
                            originalPrice: r"$161.98", extraInfo: context.t('price_per_week', args: {'price': r'$1.56'})
                          ),
                        ],
                        const SizedBox(height: 32),
                        // Collapsible Features List with Auto-Scroll
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _showFeatures = !_showFeatures);
                            if (_showFeatures) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                final context = _featuresKey.currentContext;
                                if (context != null) {
                                  Scrollable.ensureVisible(
                                    context,
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              });
                            }
                          },
                          icon: Icon(_showFeatures ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: primaryColor),
                          label: Text(
                            _showFeatures ? context.t('hide_comparison') : context.t('compare_plans'),
                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (_showFeatures) ...[
                          const SizedBox(height: 16),
                          _buildFeatureComparison(primaryColor, features),
                        ],
                      ],
                    ),
                  ),
                ),
                title: context.t('premium_unlock_title'),
                description: context.t('premium_unlock_desc'),
              ),
            ],
          ),
          // Top Overlay: Skip
          if (_currentPage < 6)
            Positioned(
              top: 20,
              right: 20,
              child: TextButton(
                onPressed: () => _finishOnboarding(skipped: true),
                child: Text(
                  context.t('onboarding_skip'),
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 16),
                ),
              ),
            ),
          // Bottom Overlay: Dots and Button
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Column(
              children: [
                if (_currentPage < 6) ...[
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
                  const SizedBox(height: 16),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: _currentPage == 6
                        ? (subService.isPremium 
                            ? ElevatedButton(
                                onPressed: () => _finishOnboarding(skipped: false),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: Colors.green.withValues(alpha: 0.1),
                                  disabledForegroundColor: Colors.green.withValues(alpha: 0.3),
                                  minimumSize: const Size(double.infinity, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  context.t('finish'),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : TextButton(
                                onPressed: () => _finishOnboarding(skipped: false),
                                child: Text(
                                  context.t('maybe_later'),
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ))
                        : ElevatedButton(
                            onPressed: (_currentPage == 1 || _currentPage == 2)
                                ? (_currentPage == 1 ? (_selectedAge != null ? () { _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); } : null) : (_selectedPillarId != null ? () { _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut); } : null))
                                : () {
                                    _pageController.nextPage(
                                      duration: const Duration(milliseconds: 300),
                                      curve: Curves.easeInOut,
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: primaryColor.withValues(alpha: 0.1),
                              disabledForegroundColor: primaryColor.withValues(alpha: 0.3),
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              context.t('onboarding_next'),
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
    );
  }

  Widget _buildPremiumSuccess(Color pillarColor) {
    final subService = context.read<SubscriptionService>();
    return Card(
      color: Colors.green,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('premium_status_active'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subService.expiryDate != null
                        ? context.t(
                          'premium_expires_at',
                          args: {
                            'date': DateFormat.yMMMMd().format(
                              subService.expiryDate!,
                            ),
                          },
                        )
                        : context.t('premium_lifetime'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscriptionOption(int index, String title, String price, String sub, {String? originalPrice, String? extraInfo}) {
    final isSelected = _selectedOptionIndex == index;

    return InkWell(
      onTap: () {
        setState(() => _selectedOptionIndex = index);
        _navigateToBilling(index);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
                if (extraInfo != null)
                  Text(
                    extraInfo,
                    style: TextStyle(
                      color: primaryColor.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureComparison(Color pillarColor, List<Map<String, dynamic>> features) {
    return Container(
      key: _featuresKey,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: SizedBox()),
              SizedBox(width: 60, child: Text(context.t('feature_free'), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
              SizedBox(width: 60, child: Text(context.t('feature_pro'), textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: pillarColor))),
            ],
          ),
          const Divider(),
          ...features.map((f) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(child: Text(f['name'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
                SizedBox(width: 60, child: Icon(f['free'] ? Icons.check_circle : Icons.cancel, size: 20, color: f['free'] ? Colors.green : Colors.grey[300])),
                SizedBox(width: 60, child: Icon(Icons.check_circle, size: 20, color: pillarColor)),
              ],
            ),
          )),
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
