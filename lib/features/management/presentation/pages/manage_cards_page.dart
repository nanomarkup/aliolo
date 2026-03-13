import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/aliolo_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/features/management/presentation/pages/subject_details_page.dart';
import 'package:aliolo/features/management/presentation/pages/subject_edit_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';

class ManageCardsPage extends StatefulWidget {
  const ManageCardsPage({super.key});

  @override
  State<ManageCardsPage> createState() => _ManageCardsPageState();
}

class _ManageCardsPageState extends State<ManageCardsPage> {
  final _cardService = CardService();
  final _authService = AuthService();
  final _searchController = TextEditingController();

  List<SubjectModel> _allSubjects = [];
  List<SubjectModel> _filteredSubjects = [];
  bool _isLoading = true;

  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      windowManager.setResizable(true);
    }
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
    final myId = _authService.currentUser?.serverId;
    final uiLang = TranslationService().currentLocale.languageCode;

    setState(() {
      _filteredSubjects =
          _allSubjects.where((s) {
            final matchesSearch = s
                .getName(uiLang)
                .toLowerCase()
                .contains(query);
            if (!matchesSearch) return false;

            if (_filter == 'mine') return s.ownerId == myId;
            if (_filter == 'public') return s.isPublic;
            if (_filter == 'dashboard') return s.isOnDashboard;

            return true;
          }).toList();

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
    const currentSessionColor = ThemeService.mainColor;
    const appBarColor = Colors.white;
    final uiLang = TranslationService().currentLocale.languageCode;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
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
                    MaterialPageRoute(
                      builder: (context) => const SubjectPage(),
                    ),
                    (route) => false,
                  ),
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
              onPressed: () => _loadData(),
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
          body:
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                    children: [
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
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
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: currentSessionColor,
                                  size: 40,
                                ),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const SubjectEditPage(),
                                    ),
                                  );
                                  if (result == true) _loadData();
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildFilterChip('all', context.t('filter_all')),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                'mine',
                                context.t('filter_my_subjects'),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                'public',
                                context.t('filter_public'),
                              ),
                              const SizedBox(width: 8),
                              _buildFilterChip(
                                'dashboard',
                                context.t('filter_on_dashboard'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                      Expanded(
                        child:
                            _filteredSubjects.isEmpty
                                ? Center(
                                  child: Text(context.t('no_subjects_found')),
                                )
                                : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 32),
                                  itemCount: _filteredSubjects.length,
                                  itemBuilder: (context, index) {
                                    final s = _filteredSubjects[index];
                                    final p = pillars.firstWhere(
                                      (item) => item.id == s.pillarId,
                                      orElse: () => pillars.first,
                                    );
                                    final myId =
                                        _authService.currentUser?.serverId;
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
                                                      SubjectDetailsPage(
                                                        subject: s,
                                                      ),
                                            ),
                                          );
                                          _loadData();
                                        },
                                        leading: Icon(
                                          p.getIconData(),
                                          color: p.getColor(),
                                        ),
                                        title: Text(
                                          s.getName(uiLang),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${s.cardCount} ${context.plural('card', s.cardCount)} • ${p.getTranslatedName(uiLang)}${!isMine ? ' • ${s.ownerName ?? '... '}' : ''}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (!isMine)
                                              Tooltip(
                                                message: context.t(
                                                  'filter_on_dashboard',
                                                ),
                                                child: Switch(
                                                  value: s.isOnDashboard,
                                                  onChanged: (val) async {
                                                    await _cardService
                                                        .toggleSubjectOnDashboard(
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
                                            if (isMine)
                                              const Icon(Icons.chevron_right),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
        );
      },
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _filter == value;
    final color = ThemeService.mainColor;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) {
          setState(() {
            _filter = value;
            _applyFilters();
          });
        }
      },
      selectedColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? color : Colors.grey[600],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}
