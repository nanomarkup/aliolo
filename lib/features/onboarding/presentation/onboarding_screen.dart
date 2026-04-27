import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:uuid/uuid.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/subscription_service.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/auth/presentation/pages/login_page.dart';
import 'package:aliolo/features/settings/presentation/pages/billing_page.dart';
import 'package:aliolo/core/network/cloudflare_client.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'slides.dart';

enum _Slide1PlaybackMode { pending, normal, mutedFallback, blocked }

class OnboardingScreen extends StatefulWidget {
  final bool isReplay;

  const OnboardingScreen({super.key, this.isReplay = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  String _sessionId = const Uuid().v4();
  final GlobalKey _featuresKey = GlobalKey();
  final _cfClient = getIt<CloudflareHttpClient>();

  int _currentPage = 0;
  double _dailyGoal = 30;
  String? _selectedAge;
  int? _selectedPillarId;
  int? _selectedOptionIndex;
  bool _showFeatures = false;
  bool _slide1VideoFinished = false;
  bool _videoVisible = false;
  bool _slide1ShowManualStart = false;
  _Slide1PlaybackMode _slide1PlaybackMode = _Slide1PlaybackMode.pending;
  bool _slide4VideoVisible = false;
  bool _slide4Resetting = false;
  int _slide1PlaybackAttempt = 0;
  int _slide4PlaybackAttempt = 0;
  StreamSubscription? _slide1Subscription;

  late VideoPlayerController _controller1;
  late VideoPlayerController _controller4;

  final Color primaryColor = const Color(0xFF1D4289);
  final Color bgColor = const Color(0xFFF1F5F9);
  final Duration _slide4FadeDuration = const Duration(milliseconds: 550);
  final Duration _slide4FadeInDelay = const Duration(milliseconds: 320);

  final List<String> ageOptions = [
    'age_under_14',
    'age_15_18',
    'age_19_25',
    'age_26_35',
    'age_36_50',
    'age_over_50',
  ];

  void _attachSlide1Listener() {
    _controller1.addListener(_handleSlide1Playback);
  }

  void _handleSlide1Playback() {
    if (_controller1.value.position >= _controller1.value.duration &&
        _controller1.value.isInitialized &&
        !_slide1VideoFinished) {
      if (mounted) {
        setState(() {
          _slide1VideoFinished = true;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initAnalytics();

    _controller1 = VideoPlayerController.asset('assets/Slide1_v7.mp4');
    _attachSlide1Listener();
    _controller1.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _startSlide1Video();
    });

    _controller4 = VideoPlayerController.asset('assets/Slide4.mp4');
    _controller4.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });
    _controller4.addListener(_handleSlide4Playback);

    final subService = getIt<SubscriptionService>();
    if (subService.activeProductId != null) {
      final activeId = subService.activeProductId!;
      if (activeId.contains('weekly')) {
        _selectedOptionIndex = 0;
      } else if (activeId.contains('yearly')) {
        _selectedOptionIndex = 2;
      } else {
        _selectedOptionIndex = 1;
      }
    }
  }

  Future<void> _initAnalytics() async {
    if (widget.isReplay) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final existingSessionId = prefs.getString(onboardingSessionIdKey);
      if (existingSessionId != null && existingSessionId.isNotEmpty) {
        _sessionId = existingSessionId;
      } else {
        await prefs.setString(onboardingSessionIdKey, _sessionId);
      }
    } catch (e) {
      debugPrint('Error initializing onboarding analytics: $e');
    }
  }

  Future<void> _updateAnalytics({
    String? ageRange,
    int? pillarId,
    int? lastSlideIndex,
  }) async {
    if (widget.isReplay) return;
    if (ageRange == null && _selectedAge == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (ageRange != null) {
        await prefs.setString(onboardingAgeRangeKey, ageRange);
      }
      if (pillarId != null) {
        await prefs.setInt(onboardingPillarIdKey, pillarId);
      }

      final updates = <String, dynamic>{'session_id': _sessionId};
      if (ageRange != null) updates['age_range'] = ageRange;
      if (pillarId != null) updates['pillar_id'] = pillarId;
      if (lastSlideIndex != null) updates['last_slide_index'] = lastSlideIndex;

      await _cfClient.client.post('/api/analytics/onboarding', data: updates);
    } catch (e) {
      debugPrint('Error updating onboarding analytics: $e');
    }
  }

  Future<void> _reinitializeSlide1Controller() async {
    final previous = _controller1;
    _controller1 = VideoPlayerController.asset('assets/Slide1_v7.mp4');
    _attachSlide1Listener();
    await _controller1.initialize();
    await previous.dispose();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _handleSlide1ManualStart() async {
    final attempt = ++_slide1PlaybackAttempt;

    if (!_controller1.value.isInitialized) {
      try {
        await _reinitializeSlide1Controller();
      } catch (e) {
        debugPrint('Onboarding manual controller reinit failed: $e');
        if (mounted && attempt == _slide1PlaybackAttempt) {
          setState(() {
            _slide1ShowManualStart = true;
            _slide1PlaybackMode = _Slide1PlaybackMode.blocked;
            _videoVisible = false;
          });
        }
        return;
      }
    }

    _controller1.pause();
    _controller1.seekTo(Duration.zero);

    if (!mounted) return;
    setState(() {
      _slide1ShowManualStart = false;
      _slide1PlaybackMode = _Slide1PlaybackMode.pending;
      _slide1VideoFinished = false;
      _videoVisible = true;
    });

    await _controller1.setVolume(1.0);
    await _controller1.play();

    Future.delayed(const Duration(milliseconds: 250), () async {
      if (!mounted ||
          attempt != _slide1PlaybackAttempt ||
          _currentPage != 0 ||
          _slide1VideoFinished) {
        return;
      }

      if (_controller1.value.isPlaying) {
        setState(() {
          _slide1PlaybackMode = _Slide1PlaybackMode.normal;
          _videoVisible = true;
        });
        return;
      }

      await _retrySlide1Muted(attempt);
    });
  }

  void _scheduleSlide1ManualStart(int attempt) {
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted ||
          attempt != _slide1PlaybackAttempt ||
          _currentPage != 0 ||
          _slide1VideoFinished ||
          _slide1PlaybackMode != _Slide1PlaybackMode.pending) {
        return;
      }

      setState(() {
        _slide1ShowManualStart = true;
      });
    });
  }

  Future<void> _startSlide1Video() async {
    if (!_controller1.value.isInitialized) return;

    final attempt = ++_slide1PlaybackAttempt;
    if (mounted) {
      setState(() {
        _slide1ShowManualStart = false;
        _slide1PlaybackMode = _Slide1PlaybackMode.pending;
        _videoVisible = false;
      });
    }
    _scheduleSlide1ManualStart(attempt);

    try {
      await _controller1.setVolume(1.0);
      await _controller1.play();
      if (!mounted || attempt != _slide1PlaybackAttempt) return;

      Future.delayed(const Duration(milliseconds: 350), () async {
        if (!mounted || attempt != _slide1PlaybackAttempt || _currentPage != 0) {
          return;
        }
        if (_controller1.value.isPlaying && !_slide1VideoFinished) {
          setState(() {
            _slide1ShowManualStart = false;
            _slide1PlaybackMode = _Slide1PlaybackMode.normal;
            _videoVisible = true;
          });
          return;
        }

        await _retrySlide1Muted(attempt);
      });
    } catch (e) {
      debugPrint('Onboarding video playback with sound blocked: $e');
      await _retrySlide1Muted(attempt);
    }
  }

  Future<void> _retrySlide1Muted(int attempt) async {
    if (!_controller1.value.isInitialized) return;
    if (!mounted || attempt != _slide1PlaybackAttempt || _currentPage != 0) {
      return;
    }

    setState(() {
      _slide1ShowManualStart = false;
      _slide1PlaybackMode = _Slide1PlaybackMode.mutedFallback;
      _videoVisible = true;
    });

    try {
      await _controller1.setVolume(0.0);
      await _controller1.play();
      if (!mounted || attempt != _slide1PlaybackAttempt) return;

      Future.delayed(const Duration(milliseconds: 250), () {
        if (!mounted ||
            attempt != _slide1PlaybackAttempt ||
            _currentPage != 0 ||
            _slide1VideoFinished) {
          return;
        }

        if (_controller1.value.isPlaying) {
          return;
        }

        setState(() {
          _slide1ShowManualStart = true;
          _slide1PlaybackMode = _Slide1PlaybackMode.blocked;
          _videoVisible = false;
        });
      });
    } catch (e) {
      debugPrint('Onboarding muted video playback blocked: $e');
      if (mounted && attempt == _slide1PlaybackAttempt) {
        setState(() {
          _slide1ShowManualStart = true;
          _slide1PlaybackMode = _Slide1PlaybackMode.blocked;
          _videoVisible = false;
        });
      }
    }
  }

  void _handlePageChange(int page) {
    setState(() {
      _currentPage = page;
      if (page != 6) _showFeatures = false;
    });

    if (page > 0) {
      _updateAnalytics(lastSlideIndex: page);
    }

    if (page == 0) {
      _controller1.seekTo(Duration.zero);
      setState(() {
        _slide1VideoFinished = false;
        _videoVisible = false;
        _slide1ShowManualStart = false;
        _slide1PlaybackMode = _Slide1PlaybackMode.pending;
      });
      _startSlide1Video();
    } else {
      _controller1.pause();
    }

    if (page == 3) {
      _startSlide4Video();
    } else {
      _slide4PlaybackAttempt++;
      _slide4Resetting = false;
      _controller4.pause();
      if (mounted) {
        setState(() {
          _slide4VideoVisible = false;
        });
      }
    }
  }

  void _startSlide4Video() {
    if (!_controller4.value.isInitialized) return;

    final attempt = ++_slide4PlaybackAttempt;
    _slide4Resetting = false;
    _controller4.seekTo(Duration.zero);
    _controller4.play();
    if (mounted) {
      setState(() {
        _slide4VideoVisible = false;
      });
    }

    Future.delayed(_slide4FadeInDelay, () {
      if (!mounted || _currentPage != 3 || attempt != _slide4PlaybackAttempt) {
        return;
      }
      setState(() {
        _slide4VideoVisible = true;
      });
    });
  }

  void _handleSlide4Playback() {
    if (!_controller4.value.isInitialized) return;
    if (_controller4.value.duration == Duration.zero) return;
    if (_slide4Resetting) return;

    final remaining = _controller4.value.duration - _controller4.value.position;
    if (remaining > const Duration(milliseconds: 120)) return;

    _slide4Resetting = true;
    final attempt = ++_slide4PlaybackAttempt;
    if (mounted) {
      setState(() {
        _slide4VideoVisible = false;
      });
    }

    Future.delayed(_slide4FadeDuration, () async {
      if (!mounted || _currentPage != 3 || attempt != _slide4PlaybackAttempt) {
        return;
      }
      await _controller4.pause();
      await _controller4.seekTo(Duration.zero);
      if (!mounted || _currentPage != 3 || attempt != _slide4PlaybackAttempt) {
        return;
      }
      setState(() {
        _slide4VideoVisible = true;
        _slide4Resetting = false;
      });
    });
  }

  Widget _buildSlide1Poster() {
    return ColoredBox(color: bgColor, child: const SizedBox.expand());
  }

  @override
  void dispose() {
    _slide1Subscription?.cancel();
    _controller1.dispose();
    _controller4.removeListener(_handleSlide4Playback);
    _controller4.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding({bool skipped = false}) async {
    if (widget.isReplay) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

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
      nextPath = const LoginPage(initialCreateAccount: true);
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
      MaterialPageRoute(
        builder: (context) => BillingPage(selectedIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String displayLang =
        getIt<TranslationService>().currentLocale.languageCode;
    final subService = context.watch<SubscriptionService>();
    context.watch<CardService>(); // Keep watching for updates
    // Use the global pillars list from pillar_model.dart

    final List<Map<String, dynamic>> features = [
      {'name': context.t('feature_full_library'), 'free': true},
      {'name': context.t('feature_spaced_repetition'), 'free': false},
      {'name': context.t('feature_creation'), 'free': false},
      {'name': context.t('feature_testing'), 'free': false},
      {'name': context.t('feature_autoplay'), 'free': false},
      {'name': context.t('feature_private_mode'), 'free': false},
      {'name': context.t('feature_customize'), 'free': false},
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
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedOpacity(
                          opacity: _slide1VideoFinished ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 300),
                          child: _buildSlide1Poster(),
                        ),
                        AnimatedOpacity(
                          opacity:
                              (_videoVisible && !_slide1VideoFinished)
                                  ? 1.0
                                  : 0.0,
                          duration: const Duration(milliseconds: 1000),
                          child:
                              _controller1.value.isInitialized
                                  ? VideoPlayer(_controller1)
                                  : Container(color: Colors.black),
                        ),
                        if (((_slide1PlaybackMode !=
                                        _Slide1PlaybackMode.normal &&
                                    _slide1PlaybackMode !=
                                        _Slide1PlaybackMode.pending) ||
                                (_slide1PlaybackMode ==
                                        _Slide1PlaybackMode.pending &&
                                    _slide1ShowManualStart)) &&
                            !_slide1VideoFinished)
                          Material(
                            color: Colors.black.withValues(alpha: 0.38),
                            child: MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Center(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (_) => _handleSlide1ManualStart(),
                                  child: Container(
                                    width: 88,
                                    height: 88,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _slide1PlaybackMode ==
                                              _Slide1PlaybackMode
                                                  .mutedFallback
                                          ? Icons.volume_up_rounded
                                          : Icons.play_arrow_rounded,
                                      color: primaryColor,
                                      size: 56,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        AnimatedOpacity(
                          opacity: _slide1VideoFinished ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 1000),
                          child: IgnorePointer(
                            ignoring: !_slide1VideoFinished,
                            child: Center(
                              child: Image.asset(
                                'assets/app_icon.webp',
                                height: 240,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                      children:
                          ageOptions.map((ageKey) {
                            final bool isSelected = _selectedAge == ageKey;
                            return InkWell(
                              onTap: () {
                                setState(() => _selectedAge = ageKey);
                                _updateAnalytics(ageRange: ageKey);
                                Future.delayed(
                                  const Duration(milliseconds: 300),
                                  () {
                                    if (mounted) {
                                      _pageController.nextPage(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        curve: Curves.easeInOut,
                                      );
                                    }
                                  },
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color:
                                      isSelected ? primaryColor : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? Colors.white.withValues(
                                              alpha: 0.8,
                                            )
                                            : Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                    width: isSelected ? 3 : 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.03,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                    if (isSelected)
                                      BoxShadow(
                                        color: primaryColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                  ],
                                ),
                                child: Text(
                                  context.t(ageKey),
                                  style: TextStyle(
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.black87,
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
                visual:
                    pillars.isEmpty
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
                              children:
                                  pillars.map((pillar) {
                                    final bool isSelected =
                                        _selectedPillarId == pillar.id;
                                    return _OnboardingPillarTile(
                                      pillar: pillar,
                                      isSelected: isSelected,
                                      displayLang: displayLang,
                                      onTap: () {
                                        setState(
                                          () => _selectedPillarId = pillar.id,
                                        );
                                        _updateAnalytics(pillarId: pillar.id);
                                        Future.delayed(
                                          const Duration(milliseconds: 300),
                                          () {
                                            if (mounted) {
                                              _pageController.nextPage(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                curve: Curves.easeInOut,
                                              );
                                            }
                                          },
                                        );
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
                visual: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller4.value.isInitialized)
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: _controller4.value.aspectRatio,
                            child: AnimatedOpacity(
                              opacity: _slide4VideoVisible ? 1.0 : 0.0,
                              duration: _slide4FadeDuration,
                              child: VideoPlayer(_controller4),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                title: context.t('onboarding_4_title'),
                description: context.t('onboarding_4_desc'),
              ),
              // Slide 5: Sync
              OnboardingSlide(
                useFixedHeader: false,
                visual: Icon(
                  Icons.cloud_sync_outlined,
                  size: 120,
                  color: primaryColor,
                ),
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
                              const Icon(
                                Icons.format_quote,
                                color: Color(0xFF1D4289),
                                size: 40,
                              ),
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
                        Image.asset(
                          'assets/Social.webp',
                          height: 60,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 4),
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
                            Row(
                              children: [
                                ...List.generate(
                                  4,
                                  (index) => const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                    size: 28,
                                  ),
                                ),
                                const Icon(
                                  Icons.star_half,
                                  color: Colors.amber,
                                  size: 28,
                                ),
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
                        const Icon(
                          Icons.workspace_premium,
                          color: Colors.amber,
                          size: 80,
                        ),
                        const SizedBox(height: 24),
                        if (subService.isPremium) ...[
                          _buildPremiumSuccess(primaryColor),
                          const SizedBox(height: 24),
                        ],

                        _buildSubscriptionOption(
                          0,
                          context.t('plan_weekly_title'),
                          r"$2.99",
                          context.t('plan_weekly_tagline'),
                          originalPrice: r"$5.98",
                          isActive:
                              subService.activeProductId?.contains('weekly') ??
                              false,
                        ),
                        const SizedBox(height: 12),
                        _buildSubscriptionOption(
                          1,
                          context.t('plan_monthly_title'),
                          r"$8.99",
                          context.t('plan_monthly_tagline'),
                          originalPrice: r"$17.98",
                          extraInfo: context.t(
                            'price_per_week',
                            args: {'price': r'$2.25'},
                          ),
                          isActive:
                              subService.activeProductId?.contains('monthly') ??
                              false,
                        ),
                        const SizedBox(height: 12),
                        _buildSubscriptionOption(
                          2,
                          context.t('plan_yearly_title'),
                          r"$80.99",
                          context.t('plan_yearly_tagline'),
                          originalPrice: r"$161.98",
                          extraInfo: context.t(
                            'price_per_week',
                            args: {'price': r'$1.56'},
                          ),
                          isActive:
                              subService.activeProductId?.contains('yearly') ??
                              false,
                        ),
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
                          icon: Icon(
                            _showFeatures
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            color: primaryColor,
                          ),
                          label: Text(
                            _showFeatures
                                ? context.t('hide_comparison')
                                : context.t('compare_plans'),
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
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
              child:
                  widget.isReplay
                      ? IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        color: const Color(0xFF64748B),
                        tooltip:
                            MaterialLocalizations.of(
                              context,
                            ).closeButtonTooltip,
                      )
                      : TextButton(
                        onPressed: () => _finishOnboarding(skipped: true),
                        child: Text(
                          context.t('onboarding_skip'),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                          ),
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
                          color:
                              _currentPage == index
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
                    child:
                        _currentPage == 6
                            ? (subService.isPremium
                                ? ElevatedButton(
                                  onPressed:
                                      () => _finishOnboarding(skipped: false),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.green
                                        .withValues(alpha: 0.1),
                                    disabledForegroundColor: Colors.green
                                        .withValues(alpha: 0.3),
                                    minimumSize: const Size(
                                      double.infinity,
                                      56,
                                    ),
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
                                  onPressed:
                                      () => _finishOnboarding(skipped: false),
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
                              onPressed:
                                  (_currentPage == 1 || _currentPage == 2)
                                      ? (_currentPage == 1
                                          ? (_selectedAge != null
                                              ? () {
                                                _pageController.nextPage(
                                                  duration: const Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                );
                                              }
                                              : null)
                                          : (_selectedPillarId != null
                                              ? () {
                                                _pageController.nextPage(
                                                  duration: const Duration(
                                                    milliseconds: 300,
                                                  ),
                                                  curve: Curves.easeInOut,
                                                );
                                              }
                                              : null))
                                      : () {
                                        _pageController.nextPage(
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                          curve: Curves.easeInOut,
                                        );
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: primaryColor
                                    .withValues(alpha: 0.1),
                                disabledForegroundColor: primaryColor
                                    .withValues(alpha: 0.3),
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

  Widget _buildSubscriptionOption(
    int index,
    String title,
    String price,
    String sub, {
    String? originalPrice,
    String? extraInfo,
    bool isActive = false,
  }) {
    final activeId = context.read<SubscriptionService>().activeProductId;
    final int defaultIndex =
        (activeId != null && activeId.contains('weekly'))
            ? 0
            : ((activeId != null && activeId.contains('yearly')) ? 2 : 1);
    final isSelected = (_selectedOptionIndex ?? defaultIndex) == index;

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
          color:
              isActive
                  ? Colors.green.withValues(alpha: 0.05)
                  : (isSelected
                      ? primaryColor.withValues(alpha: 0.05)
                      : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isActive
                    ? Colors.green
                    : (isSelected
                        ? primaryColor
                        : Colors.black.withValues(alpha: 0.1)),
            width: isActive || isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.t('current_subscription'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    sub,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
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
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isActive ? Colors.green : primaryColor,
                  ),
                ),
                if (extraInfo != null)
                  Text(
                    extraInfo,
                    style: TextStyle(
                      color:
                          isActive
                              ? Colors.green.withValues(alpha: 0.7)
                              : primaryColor.withValues(alpha: 0.7),
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

  Widget _buildFeatureComparison(
    Color pillarColor,
    List<Map<String, dynamic>> features,
  ) {
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
              SizedBox(
                width: 60,
                child: Text(
                  context.t('feature_free'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  context.t('feature_pro'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      f['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: Icon(
                      f['free'] ? Icons.check_circle : Icons.cancel,
                      size: 20,
                      color: f['free'] ? primaryColor : Colors.grey[300],
                    ),
                  ),
                  SizedBox(
                    width: 60,
                    child: const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
    final pillarColor = pillar.getColor(false);

    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side:
            isSelected
                ? BorderSide(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 3,
                )
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
              colors: [pillarColor, pillarColor.withValues(alpha: 0.8)],
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
                        Icon(
                          pillar.getIconData(),
                          color: Colors.white,
                          size: 20,
                        ),
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
