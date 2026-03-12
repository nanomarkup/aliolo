import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';

import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/management/presentation/pages/manage_cards_page.dart';
import 'package:aliolo/features/management/presentation/pages/add_card_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';

class SubjectManagementPage extends StatefulWidget {
  const SubjectManagementPage({super.key});

  @override
  State<SubjectManagementPage> createState() => _SubjectManagementPageState();
}

class _SubjectManagementPageState extends State<SubjectManagementPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _searchController = TextEditingController();

  List<SubjectModel> _allSubjects = [];
  List<SubjectModel> _filteredSubjects = [];
  bool _isLoading = true;

  bool _filterOnDashboardOnly = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final subjects = await _cardService.getManagementSubjects();
    final myId = _authService.currentUser?.serverId;

    if (mounted) {
      setState(() {
        // Only show subjects NOT owned by me
        _allSubjects = subjects.where((s) => s.ownerId != myId).toList();
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredSubjects =
          _allSubjects.where((s) {
            final matchesSearch = s.name.toLowerCase().contains(query);
            if (!matchesSearch) return false;

            if (_filterOnDashboardOnly && !s.isOnDashboard) return false;

            return true;
          }).toList();

      // Sort by Pillar ID first, then by Name
      _filteredSubjects.sort((a, b) {
        if (a.pillarId != b.pillarId) {
          return a.pillarId.compareTo(b.pillarId);
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color currentSessionColor = ThemeService.mainColor;
    const appBarColor = Colors.white;

    return ResizeWrapper(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AlioloAppBar(
          title: Text(
            context.t('manage_subjects'),
            style: const TextStyle(color: appBarColor),
          ),
          backgroundColor: currentSessionColor,
          foregroundColor: appBarColor,
          actions: [
            IconButton(
              icon: const Icon(Icons.school, color: appBarColor),
              onPressed:
                  () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SubjectPage(),
                    ),
                    (route) => false,
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.category, color: appBarColor),
              onPressed: () => _loadData(),
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardPage(),
                    ),
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.collections_bookmark, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ManageCardsPage(),
                    ),
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.person, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfilePage(),
                    ),
                  ),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: appBarColor),
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              children: [
                const SizedBox(height: 100),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.05),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.1),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText: context.t('search_subjects'),
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon:
                                    _searchController.text.isNotEmpty
                                        ? IconButton(
                                          icon: const Icon(Icons.clear),
                                          onPressed: () {
                                            _searchController.clear();
                                            _applyFilters();
                                          },
                                        )
                                        : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Theme.of(
                                  context,
                                ).cardColor.withValues(alpha: 0.5),
                              ),
                              onChanged: (_) => _applyFilters(),
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: Text(context.t('filter_on_dashboard')),
                              value: _filterOnDashboardOnly,
                              onChanged: (val) {
                                setState(() {
                                  _filterOnDashboardOnly = val;
                                  _applyFilters();
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child:
                            _isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : _filteredSubjects.isEmpty
                                ? Center(
                                  child: Text(context.t('no_subjects_found')),
                                )
                                : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: _filteredSubjects.length,
                                  itemBuilder: (context, index) {
                                    final s = _filteredSubjects[index];
                                    final p = pillars.firstWhere(
                                      (item) => item.id == s.pillarId,
                                      orElse: () => pillars.first,
                                    );
                                    return Card(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListTile(
                                        leading: Icon(
                                          p.getIconData(),
                                          color: p.getColor(),
                                        ),
                                        title: Text(
                                          s.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${s.cardCount} cards • ${p.translations[TranslationService().currentLocale.languageCode] ?? p.name}',
                                        ),
                                        trailing: Switch(
                                          value: s.isOnDashboard,
                                          onChanged: (val) async {
                                            await _cardService
                                                .toggleSubjectDashboard(
                                                  s.id,
                                                  val,
                                                );
                                            setState(() {
                                              s.isOnDashboard = val;
                                              _applyFilters();
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
