import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:aliolo/core/widgets/floating_app_bar.dart';
import 'package:window_manager/window_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/subject_model.dart';
import 'package:aliolo/data/models/card_model.dart';
import 'package:aliolo/data/models/pillar_model.dart';
import 'package:aliolo/data/services/card_service.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/widgets/window_controls.dart';
import 'package:aliolo/core/widgets/resize_wrapper.dart';
import 'package:aliolo/core/utils/logger.dart';

import 'package:aliolo/features/subjects/presentation/pages/subject_page.dart';
import 'package:aliolo/features/leaderboard/presentation/pages/leaderboard_page.dart';
import 'package:aliolo/features/management/presentation/pages/add_card_page.dart';
import 'package:aliolo/features/auth/presentation/pages/profile_page.dart';
import 'package:aliolo/features/settings/presentation/pages/settings_page.dart';

enum LibraryFilter { all, myLibrary, public, onDashboard }

class ManageCardsPage extends StatefulWidget {
  const ManageCardsPage({super.key});

  @override
  State<ManageCardsPage> createState() => _ManageCardsPageState();
}

class _ManageCardsPageState extends State<ManageCardsPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  final _searchController = TextEditingController();

  List<SubjectModel> _allSubjects = [];
  List<SubjectModel> _filteredSubjects = [];
  bool _isLoading = true;
  LibraryFilter _currentFilter = LibraryFilter.myLibrary;

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
    final myId = _authService.currentUser?.serverId;

    setState(() {
      _filteredSubjects =
          _allSubjects.where((s) {
            // Search filter
            final matchesSearch = s.name.toLowerCase().contains(query);
            if (!matchesSearch) return false;

            // Category filter
            switch (_currentFilter) {
              case LibraryFilter.all:
                return true;
              case LibraryFilter.myLibrary:
                return s.ownerId == myId;
              case LibraryFilter.public:
                return s.ownerId != myId;
              case LibraryFilter.onDashboard:
                return s.isOnDashboard;
            }
          }).toList();

      _filteredSubjects.sort((a, b) {
        if (a.pillarId != b.pillarId) return a.pillarId.compareTo(b.pillarId);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    });
  }

  Future<void> _refreshSubject(String subjectId) async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      final res =
          await Supabase.instance.client
              .from('subjects')
              .select('*, cards(id, is_deleted)')
              .eq('id', subjectId)
              .maybeSingle();

      if (res != null && mounted) {
        final updated = SubjectModel.fromJson(res);

        // Fetch current dashboard status for this specific subject
        final dashRes =
            await Supabase.instance.client
                .from('user_subjects')
                .select()
                .eq('user_id', user.serverId!)
                .eq('subject_id', subjectId)
                .maybeSingle();

        setState(() {
          final idx = _allSubjects.indexWhere((s) => s.id == subjectId);
          if (idx != -1) {
            updated.isOnDashboard =
                updated.ownerId == user.serverId || dashRes != null;
            _allSubjects[idx] = updated;
          }
          _applyFilters();
        });
      }
    } catch (e) {
      AppLogger.log('Error refreshing subject: $e');
    }
  }

  Future<void> _showSubjectDialog([SubjectModel? existing]) async {
    final nameController = TextEditingController(text: existing?.name);
    final descController = TextEditingController(text: existing?.description);
    int selectedPillar = existing?.pillarId ?? 1;
    bool isPublic = existing?.isPublic ?? false;

    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              existing == null
                  ? context.t('add_subject')
                  : context.t('edit_subject'),
            ),
            content: StatefulBuilder(
              builder: (context, setDialogState) {
                return SingleChildScrollView(
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
                        maxLines: 3,
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
                                    child: Text(context.t('pillar_${p.name}')),
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
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('cancel')),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  try {
                    SubjectModel? result;
                    if (existing == null) {
                      result = await _cardService.createSubject(
                        name,
                        selectedPillar,
                        description: descController.text.trim(),
                        isPublic: isPublic,
                      );
                    } else {
                      final updated = SubjectModel(
                        id: existing.id,
                        name: name,
                        pillarId: selectedPillar,
                        description: descController.text.trim(),
                        ownerId: existing.ownerId,
                        isPublic: isPublic,
                        createdAt: existing.createdAt,
                        updatedAt: DateTime.now(),
                        ownerName: existing.ownerName,
                        cardCount: existing.cardCount,
                        rawCards: existing.rawCards,
                        isOnDashboard: existing.isOnDashboard,
                      );
                      await Supabase.instance.client
                          .from('subjects')
                          .upsert(updated.toJson());
                      result = updated;
                    }

                    if (mounted && result != null) {
                      Navigator.pop(context);
                      setState(() {
                        if (existing == null) {
                          _allSubjects.add(result!);
                        } else {
                          final idx = _allSubjects.indexWhere(
                            (s) => s.id == existing.id,
                          );
                          if (idx != -1) _allSubjects[idx] = result!;
                        }
                        _applyFilters();
                      });
                    }
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                child: Text(context.t('save')),
              ),
            ],
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
    final myId = _authService.currentUser?.serverId;

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
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    hintText: context.t('search_subjects'),
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  onChanged: (_) => _applyFilters(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton.icon(
                                onPressed: () => _showSubjectDialog(),
                                icon: const Icon(Icons.post_add),
                                label: Text(context.t('add_subject')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: currentSessionColor,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(180, 56),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  LibraryFilter.all,
                                  context.t('filter_all'),
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  LibraryFilter.myLibrary,
                                  context.t('filter_my_subjects'),
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  LibraryFilter.public,
                                  context.t('filter_public'),
                                ),
                                const SizedBox(width: 8),
                                _buildFilterChip(
                                  LibraryFilter.onDashboard,
                                  context.t('filter_on_dashboard'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _filteredSubjects.isEmpty
                              ? Center(
                                child: Text(context.t('no_subjects_found')),
                              )
                              : ListView.builder(
                                padding: const EdgeInsets.all(24),
                                itemCount: _filteredSubjects.length,
                                itemBuilder: (context, index) {
                                  final s = _filteredSubjects[index];
                                  final isOwn = s.ownerId == myId;
                                  final pillar = pillars.firstWhere(
                                    (p) => p.id == s.pillarId,
                                    orElse: () => pillars.first,
                                  );

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    elevation: 2,
                                    child: ListTile(
                                      onTap: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) =>
                                                    SubjectCardsManagementPage(
                                                      subject: s,
                                                      pillar: pillar,
                                                    ),
                                          ),
                                        );
                                        _refreshSubject(s.id);
                                      },
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 8,
                                          ),
                                      leading: Icon(
                                        pillar.getIconData(),
                                        color: pillar.getColor(),
                                        size: 32,
                                      ),
                                      title: Text(
                                        s.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${s.cardCount} ${context.t('cards_label')} • ${isOwn ? context.t('private') : (s.ownerName ?? '...')}',
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isOwn) ...[
                                            IconButton(
                                              icon: const Icon(Icons.edit_note),
                                              onPressed:
                                                  () => _showSubjectDialog(s),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.red,
                                              ),
                                              onPressed:
                                                  () =>
                                                      _confirmDeleteSubject(s),
                                            ),
                                          ] else ...[
                                            if (!s.isOnDashboard)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.post_add,
                                                  color: Colors.green,
                                                ),
                                                onPressed: () async {
                                                  await _cardService
                                                      .toggleSubjectOnDashboard(
                                                        s.id,
                                                        true,
                                                      );
                                                  setState(() {
                                                    s.isOnDashboard = true;
                                                    _applyFilters();
                                                  });
                                                },
                                              )
                                            else
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () async {
                                                  await _cardService
                                                      .toggleSubjectOnDashboard(
                                                        s.id,
                                                        false,
                                                      );
                                                  setState(() {
                                                    s.isOnDashboard = false;
                                                    _applyFilters();
                                                  });
                                                },
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
        );
      },
    );
  }

  Widget _buildFilterChip(LibraryFilter filter, String label) {
    final isSelected = _currentFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val)
          setState(() {
            _currentFilter = filter;
            _applyFilters();
          });
      },
      selectedColor: ThemeService.mainColor.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? ThemeService.mainColor : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }
}

class SubjectCardsManagementPage extends StatefulWidget {
  final SubjectModel subject;
  final Pillar pillar;

  const SubjectCardsManagementPage({
    super.key,
    required this.subject,
    required this.pillar,
  });

  @override
  State<SubjectCardsManagementPage> createState() =>
      _SubjectCardsManagementPageState();
}

class _SubjectCardsManagementPageState
    extends State<SubjectCardsManagementPage> {
  final _cardService = getIt<CardService>();
  final _authService = getIt<AuthService>();
  List<CardModel> _cards = [];
  bool _isLoading = true;
  late bool _isOnDashboard;

  @override
  void initState() {
    super.initState();
    _isOnDashboard = widget.subject.isOnDashboard;
    _loadCards();
  }

  Future<void> _loadCards() async {
    setState(() => _isLoading = true);
    final data = await _cardService.getCardsBySubject(widget.subject.id);
    if (mounted) {
      setState(() {
        _cards = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleDashboard() async {
    final newState = !_isOnDashboard;
    await _cardService.toggleSubjectOnDashboard(widget.subject.id, newState);
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSessionColor = widget.pillar.getColor();
    const appBarColor = Colors.white;
    final myId = _authService.currentUser?.serverId;
    final isOwn = widget.subject.ownerId == myId;

    return ListenableBuilder(
      listenable: TranslationService(),
      builder: (context, _) {
        return ResizeWrapper(
          child: Scaffold(
            appBar: AppBar(
              title: DragToMoveArea(
                child: SizedBox(
                  width: double.infinity,
                  child: Text(
                    '${widget.subject.name}  •  ${_cards.length} ${context.t('cards_label')}',
                    style: const TextStyle(color: appBarColor),
                  ),
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
                if (!isOwn)
                  IconButton(
                    icon: Icon(
                      _isOnDashboard ? Icons.delete_outline : Icons.post_add,
                      color: appBarColor,
                    ),
                    onPressed: _toggleDashboard,
                  ),
                if (isOwn)
                  IconButton(
                    icon: const Icon(Icons.post_add, color: appBarColor),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => AddCardPage(
                                pillarId: widget.pillar.id,
                                initialSubjectId: widget.subject.id,
                              ),
                        ),
                      );
                      if (result == true) _loadCards();
                    },
                  ),
                const WindowControls(color: appBarColor, iconSize: 24),
              ],
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Column(
                  children: [
                    if (widget.subject.description != null &&
                        widget.subject.description!.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        color: currentSessionColor.withValues(alpha: 0.05),
                        child: Text(
                          widget.subject.description!,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    Expanded(
                      child:
                          _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _cards.isEmpty
                              ? Center(child: Text(context.t('no_cards')))
                              : GridView.builder(
                                padding: const EdgeInsets.all(24),
                                gridDelegate:
                                    const SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: 250,
                                      mainAxisSpacing: 20,
                                      crossAxisSpacing: 20,
                                      childAspectRatio: 0.75,
                                    ),
                                itemCount: _cards.length,
                                itemBuilder: (context, index) {
                                  final card = _cards[index];
                                  return Card(
                                    clipBehavior: Clip.antiAlias,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 2,
                                    child: InkWell(
                                      onTap: () async {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (context) => AddCardPage(
                                                  existingCard: card,
                                                  pillarId: widget.pillar.id,
                                                  isReadOnly: !isOwn,
                                                ),
                                          ),
                                        );
                                        if (result == true && isOwn)
                                          _loadCards();
                                      },
                                      child: Builder(
                                        builder: (context) {
                                          final path = card.imageUrl;
                                          if (path == null || path.isEmpty) {
                                            return Container(
                                              color: Colors.grey.withValues(
                                                alpha: 0.1,
                                              ),
                                              child: const Icon(
                                                Icons.image,
                                                size: 48,
                                                color: Colors.grey,
                                              ),
                                            );
                                          }
                                          if (kIsWeb ||
                                              path.startsWith('http')) {
                                            return Image.network(
                                              path,
                                              fit: BoxFit.cover,
                                            );
                                          } else if (path.startsWith(
                                            'assets/',
                                          )) {
                                            return Image.asset(
                                              path,
                                              fit: BoxFit.cover,
                                            );
                                          } else {
                                            return Image.file(
                                              File(path),
                                              fit: BoxFit.cover,
                                            );
                                          }
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
            ),
          ),
        );
      },
    );
  }
}
