import 'package:flutter/material.dart';
import 'package:aliolo/core/widgets/aliolo_page.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';

import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/management/presentation/pages/subject_details_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/management/presentation/pages/manage_cards_page.dart';
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

    if (mounted) {
      setState(() {
        _allSubjects = subjects;
        _isLoading = false;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    final query = _searchController.text.toLowerCase();
    final uiLang = TranslationService().currentLocale.languageCode;
    setState(() {
      _filteredSubjects =
          _allSubjects.where((s) {
            final matchesSearch = s
                .getName(uiLang)
                .toLowerCase()
                .contains(query);
            if (!matchesSearch) return false;

            if (_filterOnDashboardOnly && !s.isOnDashboard) return false;

            return true;
          }).toList();

      // Sort by Pillar ID first, then by Name
      _filteredSubjects.sort((a, b) {
        if (a.pillarId != b.pillarId) {
          return a.pillarId.compareTo(b.pillarId);
        }
        return a
            .getName(uiLang)
            .toLowerCase()
            .compareTo(b.getName(uiLang).toLowerCase());
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color currentSessionColor = ThemeService.mainColor;
    const appBarColor = Colors.white;
    final uiLang = TranslationService().currentLocale.languageCode;

    return AlioloPage(
      title: Text(
        context.t('manage_subjects'),
        style: const TextStyle(color: appBarColor),
      ),
      appBarColor: currentSessionColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.school, color: appBarColor),
          onPressed:
              () => Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const SubjectPage()),
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
                MaterialPageRoute(builder: (context) => const ProfilePage()),
              ),
        ),
        IconButton(
          icon: const Icon(Icons.settings, color: appBarColor),
          onPressed:
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              ),
        ),
      ],
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
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
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredSubjects.isEmpty
                    ? Center(child: Text(context.t('no_subjects_found')))
                    : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 32),
                      itemCount: _filteredSubjects.length,
                      itemBuilder: (context, index) {
                        final s = _filteredSubjects[index];
                        final p = pillars.firstWhere(
                          (item) => item.id == s.pillarId,
                          orElse: () => pillars.first,
                        );
                        final myId = _authService.currentUser?.serverId;
                        final isMine = s.ownerId == myId;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) =>
                                          SubjectDetailsPage(subject: s),
                                ),
                              );
                              _loadData();
                            },
                            leading: Icon(p.getIconData(), color: p.getColor()),
                            title: Text(
                              s.getName(uiLang),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${s.cardCount} ${context.plural('card', s.cardCount)} • ${p.getTranslatedName(uiLang)}${!isMine ? ' • ${s.ownerName ?? '... '}' : ''}',
                            ),
                            trailing: Switch(
                              value: s.isOnDashboard,
                              onChanged: (val) async {
                                await _cardService.toggleSubjectOnDashboard(
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
    );
  }
}
