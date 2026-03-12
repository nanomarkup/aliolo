import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';

class GroupedLicense {
  final String name;
  final List<List<LicenseParagraph>> licenseSections;
  final bool isAliolo;

  GroupedLicense({required this.name, required this.licenseSections, this.isAliolo = false});
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
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
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
      _groupedLicenses.add(GroupedLicense(
        name: name, 
        licenseSections: sections,
        isAliolo: name.contains('Aliolo')
      ));
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

  void _onPackageSelected(GroupedLicense license) {
    setState(() {
      _selectedLicense = license;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: 0, left: 0, right: 0, height: 60,
            child: DragToMoveArea(child: SizedBox.expand()),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 80.0), // Header height
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Row(
                      children: [
                        // Master List
                        Padding(
                          padding: const EdgeInsets.only(left: 20.0, bottom: 20.0),
                          child: SizedBox(
                            width: 300,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
                              ),
                              child: ListView.builder(
                                itemCount: _groupedLicenses.length,
                                itemBuilder: (context, index) {
                                  final license = _groupedLicenses[index];
                                  final isSelected = _selectedLicense == license;

                                  return ListTile(
                                    selected: isSelected,
                                    selectedTileColor: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                    title: Text(
                                      license.name,
                                      style: TextStyle(
                                        fontSize: 14, 
                                        fontWeight: license.isAliolo ? FontWeight.bold : FontWeight.normal,
                                        color: license.isAliolo ? Colors.orange : null
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    onTap: () => _onPackageSelected(license),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        // Detail Content
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20.0, bottom: 20.0, top: 20.0),
                            child: _selectedLicense == null 
                              ? Center(child: Text(context.t('select_package_license')))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0),
                                      child: Text(
                                        _selectedLicense!.name,
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const Divider(thickness: 2),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        controller: _scrollController,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              for (int i = 0; i < _selectedLicense!.licenseSections.length; i++) ...[
                                                if (i > 0) ...[
                                                  const SizedBox(height: 48),
                                                  Row(
                                                    children: [
                                                      Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.5))),
                                                      Padding(
                                                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                                        child: Text(
                                                          'ADDITIONAL LICENSE', 
                                                          style: TextStyle(
                                                            fontSize: 10, 
                                                            fontWeight: FontWeight.bold, 
                                                            color: Colors.grey.withValues(alpha: 0.7),
                                                            letterSpacing: 1.2
                                                          )
                                                        ),
                                                      ),
                                                      Expanded(child: Divider(color: Colors.grey.withValues(alpha: 0.5))),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 48),
                                                ],
                                                ..._selectedLicense!.licenseSections[i].map((p) {
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 12.0),
                                                    child: Text(
                                                      p.text,
                                                      style: const TextStyle(fontSize: 14, height: 1.5, fontFamily: 'monospace'),
                                                    ),
                                                  );
                                                }).toList(),
                                              ],
                                              const SizedBox(height: 40),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
          Positioned(
            top: 12, right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.arrow_back, color: Colors.orange, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                if (!kIsWeb) ...[
                  const WindowControls(color: Colors.orange, padding: false, iconSize: 28, showSeparator: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
