import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/theme/aliolo_theme.dart';
import 'package:aliolo/features/settings/presentation/pages/licenses_page.dart';
import 'package:aliolo/features/onboarding/presentation/onboarding_screen.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = info.version;
      });
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 20),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String title,
    String description,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = getIt<ThemeService>();

    return ListenableBuilder(
      listenable: Listenable.merge([TranslationService(), themeService]),
      builder: (context, _) {
        final mainColor = themeService.getSystemColor(Brightness.light);

        return Theme(
          data: AlioloTheme.build(
            seedColor: mainColor,
            brightness: Brightness.light,
          ),
          child: Scaffold(
            backgroundColor: const Color(0xFFF1F5F9),
            body: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 800;

              if (isMobile) {
                return Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 60),
                          // Brand Section (Mobile)
                          Image.asset(
                            'assets/app_icon.png',
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                          Transform.translate(
                            offset: const Offset(0, -14),
                            child: Column(
                              children: [
                                Text(
                                  'aliolo',
                                  style: GoogleFonts.poppins(
                                    fontSize: 72,
                                    fontWeight: FontWeight.w500,
                                    color: mainColor,
                                    letterSpacing: 4.0,
                                  ),
                                ),
                                Transform.translate(
                                  offset: const Offset(0, -16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24),
                                    child: Text(
                                      context.t('about_tagline'),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.roboto(
                                        fontSize: 14,
                                        color: mainColor,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '${context.t('version')} $_version',
                            style: TextStyle(fontSize: 14, color: mainColor.withValues(alpha: 0.7)),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              children: [
                                _buildSectionTitle(context, context.t('our_mission'), mainColor),
                                Text(
                                  context.t('mission_desc'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16, height: 1.6),
                                ),
                                _buildSectionTitle(context, context.t('core_features'), mainColor),
                                _buildInfoRow(context, Icons.collections, context.t('feat_multimedia_title'), context.t('feat_multimedia_desc'), mainColor),
                                _buildInfoRow(context, Icons.add_circle_outline, context.t('feat_create_share_title'), context.t('feat_create_share_desc'), mainColor),
                                _buildInfoRow(context, Icons.play_circle_outline, context.t('feat_autoplay_title'), context.t('feat_autoplay_desc'), mainColor),
                                _buildInfoRow(context, Icons.child_care, context.t('feat_ages_title'), context.t('feat_ages_desc'), mainColor),
                                _buildInfoRow(context, Icons.emoji_events, context.t('feat_gamified_title'), context.t('feat_gamified_desc'), mainColor),
                                
                                _buildSectionTitle(context, context.t('the_science'), mainColor),
                                _buildInfoRow(context, Icons.psychology, context.t('feat_science_spacing_title'), context.t('feat_science_spacing_desc'), mainColor),
                                _buildInfoRow(context, Icons.auto_graph, context.t('feat_science_smart_review_title'), context.t('feat_science_smart_review_desc'), mainColor),
                                
                                _buildSectionTitle(context, context.t('trust_privacy'), mainColor),
                                _buildInfoRow(context, Icons.sync, context.t('trust_ecosystem_title'), context.t('trust_ecosystem_desc'), mainColor),
                                _buildInfoRow(context, Icons.sync_lock, context.t('trust_sync_title'), context.t('trust_sync_desc'), mainColor),

                                const SizedBox(height: 32),
                                // Buttons
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OnboardingScreen())),
                                  icon: Icon(Icons.auto_awesome, color: mainColor),
                                  label: Text(context.t('view_onboarding')),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    foregroundColor: mainColor,
                                    side: BorderSide(color: mainColor),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomLicensesPage())),
                                  icon: Icon(Icons.description_outlined, color: mainColor),
                                  label: Text(context.t('licenses')),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    foregroundColor: mainColor,
                                    side: BorderSide(color: mainColor),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: Icon(Icons.arrow_back, color: mainColor),
                                  label: Text(context.t('back')),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    foregroundColor: mainColor,
                                    side: BorderSide(color: mainColor),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Center(
                                  child: Text(
                                    context.t('all_rights_reserved'),
                                    style: TextStyle(fontSize: 12, color: mainColor.withValues(alpha: 0.7)),
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Back button at top for mobile
                    Positioned(
                      top: 12,
                      left: 12,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: mainColor),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!kIsWeb)
                            WindowControls(
                              onlyClose: true,
                              showSeparator: false,
                              color: mainColor,
                              iconSize: 28,
                              padding: false,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Desktop Layout (Original)
              return Stack(
                children: [
                  const Positioned.fill(
                    child: DragToMoveArea(child: SizedBox.expand()),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side: Brand & Version
                      SizedBox(
                        width: 300,
                        child: DragToMoveArea(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              border: Border(
                                right: BorderSide(
                                  color: Theme.of(context).dividerColor,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Spacer(flex: 3),
                                Image.asset(
                                  'assets/app_icon.png',
                                  height: 150,
                                  fit: BoxFit.contain,
                                ),
                                Transform.translate(
                                  offset: const Offset(0, -20),
                                  child: Column(
                                    children: [
                                      Text(
                                        'aliolo',
                                        style: GoogleFonts.poppins(
                                          fontSize: 80,
                                          fontWeight: FontWeight.w500,
                                          color: mainColor,
                                          letterSpacing: 4.0,
                                        ),
                                      ),
                                      Transform.translate(
                                        offset: const Offset(0, -24),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 24),
                                          child: Text(
                                            context.t('about_tagline'),
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.roboto(
                                              fontSize: 14,
                                              color: mainColor,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '${context.t('version')} $_version',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: mainColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 48),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => const OnboardingScreen(),
                                          ),
                                        ),
                                    icon: Icon(Icons.auto_awesome, color: mainColor),
                                    label: Text(context.t('view_onboarding')),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50),
                                      foregroundColor: mainColor,
                                      side: BorderSide(color: mainColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    const CustomLicensesPage(),
                                          ),
                                        ),
                                    icon: Icon(Icons.description_outlined, color: mainColor),
                                    label: Text(context.t('licenses')),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50),
                                      foregroundColor: mainColor,
                                      side: BorderSide(color: mainColor),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24.0,
                                  ),
                                  child: OutlinedButton.icon(
                                    onPressed: () => Navigator.pop(context),
                                    icon: Icon(Icons.arrow_back, color: mainColor),
                                    label: Text(context.t('back')),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50),
                                      foregroundColor: mainColor,
                                      side: BorderSide(color: mainColor),
                                    ),
                                  ),
                                ),
                                const Spacer(flex: 4),
                                Text(
                                  context.t('all_rights_reserved'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: mainColor.withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Right side: Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(48),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(context, context.t('our_mission'), mainColor),
                              Text(
                                context.t('mission_desc'),
                                style: const TextStyle(fontSize: 18, height: 1.6),
                              ),
                              _buildSectionTitle(context, context.t('core_features'), mainColor),
                              _buildInfoRow(context, Icons.collections, context.t('feat_multimedia_title'), context.t('feat_multimedia_desc'), mainColor),
                              _buildInfoRow(context, Icons.add_circle_outline, context.t('feat_create_share_title'), context.t('feat_create_share_desc'), mainColor),
                              _buildInfoRow(context, Icons.play_circle_outline, context.t('feat_autoplay_title'), context.t('feat_autoplay_desc'), mainColor),
                              _buildInfoRow(context, Icons.child_care, context.t('feat_ages_title'), context.t('feat_ages_desc'), mainColor),
                              _buildInfoRow(context, Icons.emoji_events, context.t('feat_gamified_title'), context.t('feat_gamified_desc'), mainColor),
                              
                              _buildSectionTitle(context, context.t('the_science'), mainColor),
                              _buildInfoRow(context, Icons.psychology, context.t('feat_science_spacing_title'), context.t('feat_science_spacing_desc'), mainColor),
                              _buildInfoRow(context, Icons.auto_graph, context.t('feat_science_smart_review_title'), context.t('feat_science_smart_review_desc'), mainColor),
                              
                              _buildSectionTitle(context, context.t('trust_privacy'), mainColor),
                              _buildInfoRow(context, Icons.sync, context.t('trust_ecosystem_title'), context.t('trust_ecosystem_desc'), mainColor),
                              _buildInfoRow(context, Icons.sync_lock, context.t('trust_sync_title'), context.t('trust_sync_desc'), mainColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!kIsWeb)
                          WindowControls(
                            onlyClose: true,
                            showSeparator: false,
                            color: mainColor,
                            iconSize: 28,
                            padding: false,
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      );
    },
  );
}
}
