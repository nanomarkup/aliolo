import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/theme/aliolo_theme.dart';

const String _alioloCommercialLicenseName = 'Aliolo Commercial License';

class GroupedLicense {
  final String name;
  final List<List<LicenseParagraph>> licenseSections;
  final bool isAliolo;

  GroupedLicense({
    required this.name,
    required this.licenseSections,
    this.isAliolo = false,
  });
}

class CustomLicensesPage extends StatefulWidget {
  const CustomLicensesPage({super.key});

  @override
  State<CustomLicensesPage> createState() => _CustomLicensesPageState();
}

class _CustomLicensesPageState extends State<CustomLicensesPage> {
  final List<GroupedLicense> _groupedLicenses = [];
  GroupedLicense? _selectedLicense;
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyEvent);
    _loadLicenses();
  }

  @override
  void dispose() {
    _scrollController.dispose();
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

  Future<void> _loadLicenses() async {
    final Map<String, List<List<LicenseParagraph>>> tempGrouped = {};

    await for (final license in LicenseRegistry.licenses) {
      final name = license.packages.join(', ');
      if (!tempGrouped.containsKey(name)) {
        tempGrouped[name] = [];
      }
      tempGrouped[name]!.add(license.paragraphs.toList());
    }

    tempGrouped.forEach((name, sections) {
      _groupedLicenses.add(
        GroupedLicense(
          name: name,
          licenseSections: sections,
          isAliolo: name == _alioloCommercialLicenseName,
        ),
      );
    });

    _groupedLicenses.sort((a, b) {
      if (a.isAliolo) return -1;
      if (b.isAliolo) return 1;
      return a.name.compareTo(b.name);
    });

    if (_groupedLicenses.isNotEmpty) {
      _selectedLicense = _groupedLicenses.first;
    }
    setState(() => _isLoading = false);
  }

  Widget _buildIntroCard(BuildContext context, Color color) {
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('licenses_intro_title'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('licenses_intro_desc'),
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: bodyColor?.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseSectionTitle(
    BuildContext context,
    String title,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: color.withValues(alpha: 0.74),
        ),
      ),
    );
  }

  Widget _buildLicenseTile(
    BuildContext context,
    GroupedLicense license,
    Color color, {
    required bool isMobile,
  }) {
    final isSelected = _selectedLicense == license;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        selected: !isMobile && isSelected,
        selectedTileColor: color.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: Theme.of(context).cardColor,
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                license.isAliolo
                    ? color.withValues(alpha: 0.12)
                    : Theme.of(context).dividerColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            license.isAliolo
                ? Icons.verified_outlined
                : Icons.description_outlined,
            size: 20,
            color: license.isAliolo ? color : Theme.of(context).hintColor,
          ),
        ),
        title: Text(
          license.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isMobile ? 15 : 14,
            fontWeight: license.isAliolo ? FontWeight.bold : FontWeight.w500,
            color: license.isAliolo || isSelected ? color : null,
          ),
        ),
        subtitle:
            license.isAliolo
                ? Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    context.t('licenses_aliolo_subtitle'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
                : null,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _onPackageSelected(license, isMobile),
      ),
    );
  }

  Widget _buildLicenseSection(
    BuildContext context,
    Color color,
    String title,
    List<GroupedLicense> licenses, {
    required bool isMobile,
  }) {
    if (licenses.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLicenseSectionTitle(context, title, color),
        ...licenses.map(
          (license) =>
              _buildLicenseTile(context, license, color, isMobile: isMobile),
        ),
      ],
    );
  }

  Widget _buildLicenseCatalog(
    BuildContext context,
    Color color, {
    required bool isMobile,
  }) {
    final alioloLicenses =
        _groupedLicenses.where((license) => license.isAliolo).toList();
    final thirdPartyLicenses =
        _groupedLicenses.where((license) => !license.isAliolo).toList();

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildLicenseSection(
          context,
          color,
          context.t('licenses_aliolo_section_title'),
          alioloLicenses,
          isMobile: isMobile,
        ),
        if (thirdPartyLicenses.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildLicenseSection(
            context,
            color,
            context.t('licenses_third_party_section_title'),
            thirdPartyLicenses,
            isMobile: isMobile,
          ),
        ],
      ],
    );
  }

  void _onPackageSelected(GroupedLicense license, bool isMobile) {
    setState(() {
      _selectedLicense = license;
    });
    if (isMobile) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LicenseDetailScreen(license: license),
        ),
      );
    } else {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
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
            body: Stack(
              children: [
                const Positioned.fill(
                  child: DragToMoveArea(child: SizedBox.expand()),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 600;

                    return Column(
                      children: [
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (isMobile) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                iconSize: 28,
                                color: mainColor,
                                onPressed: () => Navigator.pop(context),
                                tooltip: context.t('back'),
                              ),
                            ] else
                              const SizedBox(width: 24),
                            Text(
                              context.t('licenses'),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: mainColor,
                              ),
                            ),
                            const Spacer(),
                            if (!isMobile) ...[
                              // Back Button styled like Close button
                              IconButton(
                                icon: const Icon(Icons.arrow_back),
                                iconSize: 28,
                                color: mainColor,
                                onPressed: () => Navigator.pop(context),
                                tooltip: context.t('back'),
                              ),
                              if (!kIsWeb)
                                Padding(
                                  padding: const EdgeInsets.only(right: 12.0),
                                  child: WindowControls(
                                    onlyClose: true,
                                    showSeparator: false,
                                    color: mainColor,
                                    iconSize: 28,
                                    padding: false,
                                  ),
                                ),
                            ],
                          ],
                        ),
                        const Divider(),
                        _buildIntroCard(context, mainColor),
                        Expanded(
                          child:
                              _isLoading
                                  ? Center(
                                    child: CircularProgressIndicator(
                                      color: mainColor,
                                    ),
                                  )
                                  : isMobile
                                  ? _buildLicenseCatalog(
                                    context,
                                    mainColor,
                                    isMobile: true,
                                  )
                                  : Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 980,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 320,
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                left: 16,
                                                bottom: 20,
                                              ),
                                              decoration: BoxDecoration(
                                                color:
                                                    Theme.of(context).cardColor,
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                                border: Border.all(
                                                  color:
                                                      Theme.of(
                                                        context,
                                                      ).dividerColor,
                                                ),
                                              ),
                                              child: _buildLicenseCatalog(
                                                context,
                                                mainColor,
                                                isMobile: false,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 18),
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 16.0,
                                                bottom: 20.0,
                                                top: 0.0,
                                              ),
                                              child:
                                                  _selectedLicense == null
                                                      ? Center(
                                                        child: Text(
                                                          context.t(
                                                            'select_package_license',
                                                          ),
                                                        ),
                                                      )
                                                      : LicenseDetailView(
                                                        license:
                                                            _selectedLicense!,
                                                        scrollController:
                                                            _scrollController,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class LicenseDetailScreen extends StatelessWidget {
  final GroupedLicense license;
  const LicenseDetailScreen({super.key, required this.license});

  @override
  Widget build(BuildContext context) {
    final themeService = getIt<ThemeService>();
    final mainColor = themeService.getSystemColor(Brightness.light);
    return Theme(
      data: AlioloTheme.build(
        seedColor: mainColor,
        brightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text(license.name, style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: mainColor,
        ),
        body: LicenseDetailView(license: license),
      ),
    );
  }
}

class LicenseDetailView extends StatelessWidget {
  final GroupedLicense license;
  final ScrollController? scrollController;

  const LicenseDetailView({
    super.key,
    required this.license,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    final isAliolo = license.isAliolo;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scrollController == null) // In mobile screen, title is in AppBar
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 16.0,
            ),
            child: Text(
              license.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: mainColor,
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(
              left: 24.0,
              right: 24.0,
              bottom: 16.0,
            ),
            child: Text(
              license.name,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: mainColor,
              ),
            ),
          ),
        const Divider(thickness: 1),
        Expanded(
          child: SingleChildScrollView(
            controller: scrollController,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < license.licenseSections.length; i++) ...[
                    if (i > 0) ...[
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'ADDITIONAL LICENSE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: Colors.grey.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                    ...license.licenseSections[i].map((p) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14.0),
                        child: Text(
                          p.text,
                          style: TextStyle(
                            fontSize: isAliolo ? 14 : 12,
                            height: isAliolo ? 1.65 : 1.4,
                            fontFamily: isAliolo ? null : 'monospace',
                            color: bodyColor,
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
