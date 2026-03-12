import 'package:flutter/material.dart';
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
      _filteredSubjects = _allSubjects.where((s) {
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
    const currentSessionColor = ThemeService.mainColor;
    const appBarColor = Colors.white;

    return ResizeWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: DragToMoveArea(
            child: SizedBox(
              width: double.infinity,
              child: Text(context.t('manage_subjects'), style: const TextStyle(color: appBarColor)),
            ),
          ),
          backgroundColor: currentSessionColor,
          foregroundColor: appBarColor,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.school, color: appBarColor),
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const SubjectPage()), (route) => false),
            ),
            IconButton(
              icon: const Icon(Icons.category, color: appBarColor),
              onPressed: () => _loadData(),
            ),
            IconButton(
              icon: const Icon(Icons.emoji_events, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeaderboardPage())),
            ),
            IconButton(
              icon: const Icon(Icons.style, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ManageCardsPage())),
            ),
            IconButton(
              icon: const Icon(Icons.person, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
            ),
            IconButton(
              icon: const Icon(Icons.settings, color: appBarColor),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage())),
            ),
            const WindowControls(color: appBarColor, iconSize: 24),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: context.t('search_subjects'),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty 
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (val) => _applyFilters(),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _sectionLabel(context.t('status')),
                      const SizedBox(width: 12),
                      _filterChip(context.t('on_dashboard'), _filterOnDashboardOnly, (v) => setState(() { _filterOnDashboardOnly = v; _applyFilters(); })),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _filteredSubjects.isEmpty 
                  ? Center(child: Text(context.t('no_subjects_found')))
                  : ListView.builder(
                      padding: const EdgeInsets.all(24),
                      itemCount: _filteredSubjects.length,
                      itemBuilder: (context, index) {
                        final s = _filteredSubjects[index];
                        final pillar = pillars.firstWhere((p) => p.id == s.pillarId, orElse: () => pillars.first);
                        final langCode = TranslationService().currentLocale.languageCode.toLowerCase();
                        final pillarName = pillar.translations[langCode] ?? pillar.translations['en'] ?? pillar.name;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: s.isOnDashboard ? 2 : 0.5,
                          child: ListTile(
                            onTap: () async {
                              final refresh = await Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => SubjectDetailsPage(subject: s, pillar: pillar))
                              );
                              if (refresh == true) _loadData();
                            },
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Icon(
                              pillar.getIconData(),
                              color: pillar.getColor(),
                              size: 32,
                            ),
                            title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('$pillarName • ${s.cardCount} ${context.t('cards_label')}'),
                                    const SizedBox(width: 8),
                                    Text('• ${context.t('by_author', args: {'name': s.ownerName ?? '...'})}'),
                                  ],
                                ),
                              ],
                            ),
                            trailing: ElevatedButton.icon(
                              onPressed: () async {
                                final newStatus = !s.isOnDashboard;
                                await _cardService.toggleSubjectOnDashboard(s.id, newStatus);
                                if (mounted) {
                                  setState(() {
                                    s.isOnDashboard = newStatus;
                                    _applyFilters(); // Re-apply filters in case "Dashboard Only" is active
                                  });
                                }
                              },
                              icon: Icon(s.isOnDashboard ? Icons.remove : Icons.add),
                              label: Text(s.isOnDashboard ? context.t('remove') : context.t('add_to_dashboard')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: s.isOnDashboard ? Colors.red[50] : Colors.green[50],
                                foregroundColor: s.isOnDashboard ? Colors.red : Colors.green,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2),
    );
  }

  Widget _filterChip(String label, bool selected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      selectedColor: ThemeService.mainColor.withValues(alpha: 0.2),
      checkmarkColor: ThemeService.mainColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class SubjectDetailsPage extends StatefulWidget {
  final SubjectModel subject;
  final Pillar pillar;

  const SubjectDetailsPage({super.key, required this.subject, required this.pillar});

  @override
  State<SubjectDetailsPage> createState() => _SubjectDetailsPageState();
}

class _SubjectDetailsPageState extends State<SubjectDetailsPage> {
  final cardService = getIt<CardService>();

  @override
  Widget build(BuildContext context) {
    final currentSessionColor = widget.pillar.getColor();
    const appBarColor = Colors.white;

    return ResizeWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: DragToMoveArea(
            child: SizedBox(
              width: double.infinity,
              child: Text(widget.subject.name, style: const TextStyle(color: appBarColor)),
            ),
          ),
          backgroundColor: currentSessionColor,
          foregroundColor: appBarColor,
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: appBarColor),
              onPressed: () => Navigator.pop(context),
            ),
            const WindowControls(color: appBarColor, iconSize: 24),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              color: currentSessionColor.withValues(alpha: 0.05),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(widget.pillar.getIconData(), color: currentSessionColor, size: 32),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(context.t('by_author', args: {'name': widget.subject.ownerName ?? '...'}), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          Text('${widget.subject.cardCount} ${context.t('cards_label')}', style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () async {
                          await cardService.toggleSubjectOnDashboard(widget.subject.id, !widget.subject.isOnDashboard);
                          if (mounted) Navigator.pop(context, true); // Return true to signal refresh
                        },
                        icon: Icon(widget.subject.isOnDashboard ? Icons.remove : Icons.add),
                        label: Text(widget.subject.isOnDashboard ? context.t('remove') : context.t('add_to_dashboard')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.subject.isOnDashboard ? Colors.red[50] : Colors.green[50],
                          foregroundColor: widget.subject.isOnDashboard ? Colors.red : Colors.green,
                          minimumSize: const Size(180, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                  if (widget.subject.description != null && widget.subject.description!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(widget.subject.description!, style: const TextStyle(fontSize: 16, height: 1.5)),
                  ],
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<CardModel>>(
                future: cardService.getCardsBySubject(widget.subject.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.isEmpty) return Center(child: Text(context.t('no_cards_found')));
                  
                  final cards = snapshot.data!;
                  return GridView.builder(
                    padding: const EdgeInsets.all(24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 20,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (context) => AddCardPage(
                              existingCard: card,
                              pillarId: widget.pillar.id,
                              isReadOnly: true,
                            ))
                          ),
                          child: card.imageUrl != null 
                            ? Image.network(card.imageUrl!, fit: BoxFit.cover)
                            : Container(color: Colors.grey[200], child: const Icon(Icons.image, color: Colors.grey)),
                        ),
                      );
                    },
                  );
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
}
