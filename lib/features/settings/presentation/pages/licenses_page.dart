import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';

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
          isAliolo: name.contains('Aliolo'),
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
    final orangeColor = getIt<ThemeService>().getAdjustedPrimary(forceOrange: true);

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return Scaffold(
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
                              color: orangeColor,
                              onPressed: () => Navigator.pop(context),
                              tooltip: context.t('back'),
                            ),
                          ] else
                            const SizedBox(width: 24),
                          Text(
                            context.t('licenses'),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          if (!isMobile) ...[
                            // Back Button styled like Close button
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              iconSize: 28,
                              color: orangeColor,
                              onPressed: () => Navigator.pop(context),
                              tooltip: context.t('back'),
                            ),
                            if (!kIsWeb)
                              Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: WindowControls(
                                  onlyClose: true,
                                  showSeparator: false,
                                  color: orangeColor,
                                  iconSize: 28,
                                  padding: false,
                                ),
                              ),
                          ],
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: _isLoading
                            ? Center(child: CircularProgressIndicator(color: orangeColor))
                            : isMobile
                                ? ListView.builder(
                                    itemCount: _groupedLicenses.length,
                                    itemBuilder: (context, index) {
                                      final license = _groupedLicenses[index];
                                      return ListTile(
                                        title: Text(
                                          license.name,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: license.isAliolo
                                                ? FontWeight.bold
                                                : FontWeight.normal,
                                            color: license.isAliolo
                                                ? orangeColor
                                                : null,
                                          ),
                                        ),
                                        trailing: const Icon(Icons.chevron_right),
                                        onTap: () => _onPackageSelected(license, true),
                                      );
                                    },
                                  )
                                : Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 900,
                                      ),
                                      child: Row(
                                        children: [
                                          // Master List
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 20.0,
                                            ),
                                            child: SizedBox(
                                              width: 250,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    right: BorderSide(
                                                      color: Theme.of(context)
                                                          .dividerColor,
                                                    ),
                                                  ),
                                                ),
                                                child: ListView.builder(
                                                  itemCount:
                                                      _groupedLicenses.length,
                                                  itemBuilder: (context, index) {
                                                    final license =
                                                        _groupedLicenses[index];
                                                    final isSelected =
                                                        _selectedLicense ==
                                                            license;

                                                    return ListTile(
                                                      selected: isSelected,
                                                      selectedTileColor: orangeColor.withValues(alpha: 0.1),
                                                      title: Text(
                                                        license.name,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              license.isAliolo
                                                                  ? FontWeight
                                                                      .bold
                                                                  : FontWeight
                                                                      .normal,
                                                          color:
                                                              license.isAliolo || isSelected
                                                                  ? orangeColor
                                                                  : null,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                      onTap: () =>
                                                          _onPackageSelected(
                                                              license, false),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          // Detail Content
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 0.0,
                                                bottom: 20.0,
                                                top: 0.0,
                                              ),
                                              child: _selectedLicense == null
                                                  ? Center(
                                                      child: Text(
                                                        context.t(
                                                          'select_package_license',
                                                        ),
                                                      ),
                                                    )
                                                  : LicenseDetailView(
                                                      license: _selectedLicense!,
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
    final orangeColor = getIt<ThemeService>().getAdjustedPrimary(forceOrange: true);
    return Scaffold(
      appBar: AppBar(
        title: Text(license.name, style: const TextStyle(fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: orangeColor,
      ),
      body: LicenseDetailView(license: license),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (scrollController == null) // In mobile screen, title is in AppBar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Text(
              license.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
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
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(
                          p.text,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            fontFamily: 'monospace',
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

