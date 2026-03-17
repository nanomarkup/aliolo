import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/features/settings/presentation/pages/licenses_page.dart';
import 'package:aliolo/features/onboarding/presentation/pages/onboarding_page.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  String _version = '1.0.0';

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _loadPackageInfo();
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyEvent);
    super.dispose();
  }

  bool _handleGlobalKeyEvent(KeyEvent event) {
    if (!ModalRoute.of(context)!.isCurrent) return false;
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (mounted) Navigator.pop(context);
      return true;
    }
    return false;
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _version = info.version;
    });
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 20),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              color: Colors.orange,
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
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: Colors.orange),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
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
    final currentPrimaryColor = ThemeService().primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return Scaffold(
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
                          const Icon(Icons.school, size: 80, color: Colors.orange),
                          const SizedBox(height: 12),
                          const Text(
                            'Aliolo',
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              context.t('pro_label'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${context.t('version')} $_version',
                            style: const TextStyle(fontSize: 14, color: Colors.grey),
                          ),

                          // Features Section (Mobile)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('our_mission'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  context.t('mission_desc'),
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: isDark ? Colors.grey.shade200 : Colors.grey.shade900,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                                _buildSectionTitle(context, context.t('core_features')),
                                _buildInfoRow(context, Icons.play_circle_fill, context.t('feat_multimedia_title'), context.t('feat_multimedia_desc')),
                                _buildInfoRow(context, Icons.family_restroom, context.t('feat_ages_title'), context.t('feat_ages_desc')),
                                _buildInfoRow(context, Icons.military_tech, context.t('feat_gamified_title'), context.t('feat_gamified_desc')),

                                _buildSectionTitle(context, context.t('the_science')),
                                _buildInfoRow(context, Icons.auto_graph, context.t('feat_science_spacing_title'), context.t('feat_science_spacing_desc')),
                                _buildInfoRow(context, Icons.insights, context.t('feat_science_adaptive_title'), context.t('feat_science_adaptive_desc')),

                                _buildSectionTitle(context, context.t('trust_privacy')),
                                _buildInfoRow(context, Icons.cloud_done, context.t('trust_cloud_title'), context.t('trust_cloud_desc')),
                                _buildInfoRow(context, Icons.sync_lock, context.t('trust_sync_title'), context.t('trust_sync_desc')),

                                const SizedBox(height: 32),
                                // Buttons (Mobile)
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CustomLicensesPage())),
                                  icon: const Icon(Icons.description_outlined),
                                  label: Text(context.t('licenses')),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(color: Colors.orange),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const OnboardingPage())),
                                  icon: const Icon(Icons.auto_awesome),
                                  label: Text(context.t('view_onboarding')),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(color: Colors.orange),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.arrow_back),
                                  label: Text(context.t('back')),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(double.infinity, 50),
                                    foregroundColor: Colors.orange,
                                    side: const BorderSide(color: Colors.orange),
                                  ),
                                ),
                                const SizedBox(height: 32),
                                Center(
                                  child: Text(
                                    context.t('all_rights_reserved'),
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                        icon: const Icon(Icons.arrow_back, color: Colors.orange),
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
                              color: currentPrimaryColor,
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
                                const Icon(
                                  Icons.school,
                                  size: 100,
                                  color: Colors.orange,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Aliolo',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    context.t('pro_label'),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${context.t('version')} $_version',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
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
                                                (context) =>
                                                    const CustomLicensesPage(),
                                          ),
                                        ),
                                    icon: const Icon(Icons.description_outlined),
                                    label: Text(context.t('licenses')),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50),
                                      foregroundColor: Colors.orange,
                                      side: const BorderSide(color: Colors.orange),
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
                                                (context) => const OnboardingPage(),
                                          ),
                                        ),
                                    icon: const Icon(Icons.auto_awesome),
                                    label: Text(context.t('view_onboarding')),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50),
                                      foregroundColor: Colors.orange,
                                      side: const BorderSide(color: Colors.orange),
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
                                    icon: const Icon(Icons.arrow_back),
                                    label: Text(context.t('back')),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 50),
                                      foregroundColor: Colors.orange,
                                      side: const BorderSide(color: Colors.orange),
                                    ),
                                  ),
                                ),
                                const Spacer(flex: 2),
                                Text(
                                  context.t('all_rights_reserved'),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Right side: Features & Details
                      Expanded(
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(64, 48, 64, 64),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.t('our_mission'),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2.0,
                                    color: Colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  context.t('mission_desc'),
                                  style: TextStyle(
                                    fontSize: 22,
                                    color:
                                        isDark
                                            ? Colors.grey.shade200
                                            : Colors.grey.shade900,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),

                                _buildSectionTitle(
                                  context,
                                  context.t('core_features'),
                                ),
                                _buildInfoRow(
                                  context,
                                  Icons.play_circle_fill,
                                  context.t('feat_multimedia_title'),
                                  context.t('feat_multimedia_desc'),
                                ),
                                _buildInfoRow(
                                  context,
                                  Icons.family_restroom,
                                  context.t('feat_ages_title'),
                                  context.t('feat_ages_desc'),
                                ),
                                _buildInfoRow(
                                  context,
                                  Icons.military_tech,
                                  context.t('feat_gamified_title'),
                                  context.t('feat_gamified_desc'),
                                ),

                                _buildSectionTitle(
                                  context,
                                  context.t('the_science'),
                                ),
                                _buildInfoRow(
                                  context,
                                  Icons.auto_graph,
                                  context.t('feat_science_spacing_title'),
                                  context.t('feat_science_spacing_desc'),
                                ),
                                _buildInfoRow(
                                  context,
                                  Icons.insights,
                                  context.t('feat_science_adaptive_title'),
                                  context.t('feat_science_adaptive_desc'),
                                ),

                                _buildSectionTitle(
                                  context,
                                  context.t('trust_privacy'),
                                ),
                                _buildInfoRow(
                                  context,
                                  Icons.cloud_done,
                                  context.t('trust_cloud_title'),
                                  context.t('trust_cloud_desc'),
                                ),
                                _buildInfoRow(
                                  context,
                                  Icons.sync_lock,
                                  context.t('trust_sync_title'),
                                  context.t('trust_sync_desc'),
                                ),
                                const SizedBox(height: 48),
                              ],
                            ),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!kIsWeb)
                          WindowControls(
                            onlyClose: true,
                            showSeparator: false,
                            color: currentPrimaryColor,
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
        );
      },
    );
  }
}
