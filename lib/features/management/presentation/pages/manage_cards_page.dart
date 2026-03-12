import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:window_manager/window_manager.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/features/management/presentation/pages/add_card_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';
import 'package:aliolo/features/subjects/presentation/pages/sub_subject_page.dart';

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

    setState(() {
      _filteredSubjects =
          _allSubjects.where((s) {
            final matchesSearch = s.name.toLowerCase().contains(query);
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
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    });
  }

  void _showSubjectDialog({SubjectModel? existing}) {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final descController = TextEditingController(
      text: existing?.description ?? '',
    );
    int selectedPillar = existing?.pillarId ?? 1;
    bool isPublic = existing?.isPublic ?? false;

    showDialog(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text(
                    existing == null
                        ? context.t('add_subject')
                        : context.t('edit_subject'),
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: context.t('name'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: descController,
                          decoration: InputDecoration(
                            labelText: context.t('description'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          value: selectedPillar,
                          decoration: InputDecoration(
                            labelText: context.t('pillar'),
                          ),
                          items:
                              pillars
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(
                                        context.t('pillar_${p.name}'),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            if (val != null)
                              setDialogState(() => selectedPillar = val);
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: Text(context.t('public_subject')),
                          subtitle: Text(context.t('public_subject_desc')),
                          value: isPublic,
                          onChanged:
                              (val) => setDialogState(() => isPublic = val),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.t('cancel')),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          final now = DateTime.now();
                          final subject = SubjectModel(
                            id: existing?.id ?? _cardService.generateId(),
                            name: nameController.text,
                            description: descController.text,
                            pillarId: selectedPillar,
                            ownerId: _authService.currentUser!.serverId!,
                            ownerName: _authService.currentUser!.username,
                            isPublic: isPublic,
                            isOnDashboard: existing?.isOnDashboard ?? true,
                            cardCount: existing?.cardCount ?? 0,
                            createdAt: existing?.createdAt ?? now,
                            updatedAt: now,
                          );

                          await _cardService.saveSubject(subject);
                          if (context.mounted) {
                            Navigator.pop(context);
                            _loadData();
                          }
                        } catch (e) {
                          if (context.mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                        }
                      },
                      child: Text(context.t('save')),
                    ),
                  ],
                ),
          ),
    );
  }

  Future<void> _confirmDeleteSubject(SubjectModel s) async {
    final cardCount = s.cardCount;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(context.t('delete_subject')),
                content: Text(
                  cardCount > 0
                      ? 'This subject contains $cardCount cards. Deleting it will permanently remove all of them. Are you sure?'
                      : 'Are you sure you want to delete this empty subject?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(context.t('cancel')),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text(context.t('delete')),
                  ),
                ],
              ),
        ) ??
        false;

    if (confirmed) {
      try {
        await _cardService.deleteSubjectById(s.id);
        if (mounted) {
          setState(() {
            _allSubjects.removeWhere((item) => item.id == s.id);
            _applyFilters();
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.t('subject_deleted'))));
        }
      } catch (e) {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const currentSessionColor = ThemeService.mainColor;
    const appBarColor = Colors.white;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
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
                  icon: const Icon(
                    Icons.collections_bookmark,
                    color: appBarColor,
                  ),
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
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      Column(
                        children: [
                          const SizedBox(height: 16),
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
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  color: currentSessionColor,
                                  size: 32,
                                ),
                                onPressed: () => _showSubjectDialog(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
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
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) => SubSubjectPage(
                                                    subject: s,
                                                  ),
                                            ),
                                          );
                                        },
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
                                          '${s.cardCount} cards • ${p.translations[TranslationService().currentLocale.languageCode] ?? p.name}${!isMine ? ' • ${s.ownerName ?? '... '}' : ''}',
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Dashboard Toggle Switch
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
                                            IconButton(
                                              icon: const Icon(Icons.add),
                                              onPressed:
                                                  () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder:
                                                          (
                                                            context,
                                                          ) => AddCardPage(
                                                            initialSubjectId:
                                                                s.id,
                                                            pillarId:
                                                                s.pillarId,
                                                          ),
                                                    ),
                                                  ),
                                            ),
                                            if (isMine) ...[
                                              IconButton(
                                                icon: const Icon(Icons.edit),
                                                onPressed:
                                                    () => _showSubjectDialog(
                                                      existing: s,
                                                    ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.delete),
                                                onPressed:
                                                    () => _confirmDeleteSubject(
                                                      s,
                                                    ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
