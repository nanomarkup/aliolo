import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/theme/aliolo_theme.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/features/onboarding/presentation/onboarding_screen.dart';
import 'package:aliolo/features/settings/presentation/pages/licenses_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:window_manager/window_manager.dart';

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
    if (!mounted) return;
    setState(() {
      _version = info.version;
    });
  }

  List<_AboutSection> _buildSections(BuildContext context) {
    return [
      _AboutSection(
        title: context.t('about_intro_title'),
        description: context.t('about_intro_desc'),
        items: [
          _AboutItem(
            icon: Icons.play_circle_outline,
            title: context.t('about_intro_start_title'),
            description: context.t('about_intro_start_desc'),
          ),
          _AboutItem(
            icon: Icons.groups_2_outlined,
            title: context.t('about_intro_audience_title'),
            description: context.t('about_intro_audience_desc'),
          ),
        ],
      ),
      _AboutSection(
        title: context.t('about_learn_title'),
        items: [
          _AboutItem(
            icon: Icons.auto_awesome,
            title: context.t('about_learn_modes_title'),
            description: context.t('about_learn_modes_desc'),
          ),
          _AboutItem(
            icon: Icons.language,
            title: context.t('about_learn_language_title'),
            description: context.t('about_learn_language_desc'),
          ),
          _AboutItem(
            icon: Icons.perm_media_outlined,
            title: context.t('about_learn_media_title'),
            description: context.t('about_learn_media_desc'),
          ),
          _AboutItem(
            icon: Icons.tune,
            title: context.t('about_learn_discovery_title'),
            description: context.t('about_learn_discovery_desc'),
          ),
        ],
      ),
      _AboutSection(
        title: context.t('about_organize_title'),
        items: [
          _AboutItem(
            icon: Icons.style,
            title: context.t('about_organize_subjects_title'),
            description: context.t('about_organize_subjects_desc'),
          ),
          _AboutItem(
            icon: Icons.folder_outlined,
            title: context.t('about_organize_folders_title'),
            description: context.t('about_organize_folders_desc'),
          ),
          _AboutItem(
            icon: Icons.collections_bookmark_outlined,
            title: context.t('about_organize_collections_title'),
            description: context.t('about_organize_collections_desc'),
          ),
          _AboutItem(
            icon: Icons.public,
            title: context.t('about_organize_creation_title'),
            description: context.t('about_organize_creation_desc'),
          ),
        ],
      ),
      _AboutSection(
        title: context.t('about_progress_title'),
        items: [
          _AboutItem(
            icon: Icons.stars,
            title: context.t('about_progress_xp_title'),
            description: context.t('about_progress_xp_desc'),
          ),
          _AboutItem(
            icon: Icons.track_changes,
            title: context.t('about_progress_goals_title'),
            description: context.t('about_progress_goals_desc'),
          ),
          _AboutItem(
            icon: Icons.emoji_events,
            title: context.t('about_progress_social_title'),
            description: context.t('about_progress_social_desc'),
          ),
        ],
      ),
      _AboutSection(
        title: context.t('about_support_title'),
        items: [
          _AboutItem(
            icon: Icons.settings_outlined,
            title: context.t('about_support_settings_title'),
            description: context.t('about_support_settings_desc'),
          ),
          _AboutItem(
            icon: Icons.help_outline,
            title: context.t('about_support_docs_title'),
            description: context.t('about_support_docs_desc'),
          ),
          _AboutItem(
            icon: Icons.feedback_outlined,
            title: context.t('about_support_feedback_title'),
            description: context.t('about_support_feedback_desc'),
          ),
          _AboutItem(
            icon: Icons.auto_awesome_outlined,
            title: context.t('about_support_onboarding_title'),
            description: context.t('about_support_onboarding_desc'),
          ),
          _AboutItem(
            icon: Icons.description_outlined,
            title: context.t('about_support_licenses_title'),
            description: context.t('about_support_licenses_desc'),
          ),
        ],
      ),
    ];
  }

  Widget _buildSectionCard(
    BuildContext context,
    _AboutSection section,
    Color color, {
    required Color backgroundColor,
  }) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (section.description != null &&
              section.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              section.description!,
              style: TextStyle(
                fontSize: 15,
                height: 1.55,
                color: bodyColor?.withValues(alpha: 0.82),
              ),
            ),
          ],
          const SizedBox(height: 18),
          ...section.items.asMap().entries.expand(
            (entry) => [
              if (entry.key != 0) const SizedBox(height: 16),
              _buildAboutItemRow(context, entry.value, color),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAboutItemRow(
    BuildContext context,
    _AboutItem item,
    Color color,
  ) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(item.icon, size: 22, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: color,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                item.description,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: bodyColor?.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context, Color color) {
    final buttons = [
      (
        icon: Icons.auto_awesome,
        label: context.t('view_onboarding'),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OnboardingScreen(isReplay: true),
              ),
            ),
      ),
      (
        icon: Icons.description_outlined,
        label: context.t('licenses'),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CustomLicensesPage(),
              ),
            ),
      ),
      (
        icon: Icons.arrow_back,
        label: context.t('back'),
        onTap: () => Navigator.pop(context),
      ),
    ];

    return Column(
      children:
          buttons
              .map(
                (button) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: OutlinedButton.icon(
                    onPressed: button.onTap,
                    icon: Icon(button.icon, color: color),
                    label: Text(button.label),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      foregroundColor: color,
                      side: BorderSide(color: color),
                    ),
                  ),
                ),
              )
              .toList(),
    );
  }

  Widget _buildBrandPanel(
    BuildContext context,
    Color color, {
    required bool compact,
  }) {
    return Column(
      children: [
        SizedBox(height: compact ? 56 : 24),
        Image.asset(
          'assets/app_icon.webp',
          height: compact ? 108 : 150,
          fit: BoxFit.contain,
        ),
        Transform.translate(
          offset: Offset(0, compact ? -12 : -20),
          child: Column(
            children: [
              Text(
                'aliolo',
                style: GoogleFonts.poppins(
                  fontSize: compact ? 60 : 80,
                  fontWeight: FontWeight.w500,
                  color: color,
                  letterSpacing: 4.0,
                ),
              ),
              Transform.translate(
                offset: Offset(0, compact ? -14 : -24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    context.t('about_tagline'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: color,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Text(
          '${context.t('version')} $_version',
          style: TextStyle(
            fontSize: compact ? 14 : 16,
            color: color.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    Color color,
    List<_AboutSection> sections,
  ) {
    if (sections.isEmpty) {
      return const SizedBox.shrink();
    }

    final neutralBackground = Theme.of(context).colorScheme.surface;
    final introBackground = color.withValues(alpha: 0.08);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionCard(
          context,
          sections.first,
          color,
          backgroundColor: introBackground,
        ),
        ...sections
            .skip(1)
            .map(
              (section) => _buildSectionCard(
                context,
                section,
                color,
                backgroundColor: neutralBackground,
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = getIt<ThemeService>();

    return ListenableBuilder(
      listenable: Listenable.merge([TranslationService(), themeService]),
      builder: (context, _) {
        final mainColor = themeService.getSystemColor(Brightness.light);
        final sections = _buildSections(context);

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
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 36),
                        child: Column(
                          children: [
                            _buildBrandPanel(context, mainColor, compact: true),
                            const SizedBox(height: 8),
                            _buildContent(context, mainColor, sections),
                            const SizedBox(height: 20),
                            _buildActions(context, mainColor),
                            const SizedBox(height: 16),
                            Text(
                              context.t('all_rights_reserved'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: mainColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        child:
                            !kIsWeb
                                ? WindowControls(
                                  onlyClose: true,
                                  showSeparator: false,
                                  color: mainColor,
                                  iconSize: 28,
                                  padding: false,
                                )
                                : const SizedBox.shrink(),
                      ),
                    ],
                  );
                }

                return Stack(
                  children: [
                    const Positioned.fill(
                      child: DragToMoveArea(child: SizedBox.expand()),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 320,
                          child: DragToMoveArea(
                            child: Container(
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).scaffoldBackgroundColor,
                                border: Border(
                                  right: BorderSide(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  24,
                                  24,
                                  24,
                                  24,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Spacer(flex: 2),
                                    _buildBrandPanel(
                                      context,
                                      mainColor,
                                      compact: false,
                                    ),
                                    const SizedBox(height: 36),
                                    _buildActions(context, mainColor),
                                    const Spacer(flex: 3),
                                    Text(
                                      context.t('all_rights_reserved'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: mainColor.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(48, 32, 48, 48),
                            child: _buildContent(context, mainColor, sections),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child:
                          !kIsWeb
                              ? WindowControls(
                                onlyClose: true,
                                showSeparator: false,
                                color: mainColor,
                                iconSize: 28,
                                padding: false,
                              )
                              : const SizedBox.shrink(),
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

class _AboutSection {
  final String title;
  final String? description;
  final List<_AboutItem> items;

  const _AboutSection({
    required this.title,
    this.description,
    required this.items,
  });
}

class _AboutItem {
  final IconData icon;
  final String title;
  final String description;

  const _AboutItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
