import 'package:flutter/material.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/data/models/feedback_model.dart';
import 'package:aliolo/data/services/feedback_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/features/management/presentation/pages/feedback_detail_page.dart';
import 'package:aliolo/data/services/auth_service.dart';

class FeedbackManagementPage extends StatefulWidget {
  const FeedbackManagementPage({super.key});

  @override
  State<FeedbackManagementPage> createState() => _FeedbackManagementPageState();
}

class _FeedbackManagementPageState extends State<FeedbackManagementPage> {
  final _feedbackService = getIt<FeedbackService>();
  final _authService = getIt<AuthService>();
  List<FeedbackModel> _feedbacks = [];
  bool _isLoading = true;
  String _filterType = 'all';
  late String _filterStatus;

  bool get _isAdmin =>
      _authService.currentUser?.serverId ==
      'f2fb4c9c-169b-447d-b8a6-dce72c4ed5ac';

  @override
  void initState() {
    super.initState();
    // Default: Admin wants to see 'open' (user waiting), User wants to see 'replied' (admin answered)
    _filterStatus = _isAdmin ? 'open' : 'replied';
    _loadFeedbacks();
  }

  Future<void> _loadFeedbacks() async {
    setState(() => _isLoading = true);
    final results = await _feedbackService.getFeedbacks();
    if (mounted) {
      setState(() {
        _feedbacks = results;
        _isLoading = false;
      });
    }
  }

  List<FeedbackModel> get _filteredFeedbacks {
    return _feedbacks.where((f) {
      final matchesType = _filterType == 'all' || f.type == _filterType;
      bool matchesStatus = true;
      if (_filterStatus != 'all') {
        matchesStatus = f.status == _filterStatus;
      }
      return matchesType && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ThemeService().primaryColor;
    const appBarColor = Colors.white;

    return AlioloScrollablePage(
      title: Text(
        context.t('feedback_management_title'),
        style: const TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
      ),
      appBarColor: themeColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: appBarColor),
          onPressed: _loadFeedbacks,
        ),
      ],
      fixedBody: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('type', 'all', context.t('filter_all')),
                  const SizedBox(width: 8),
                  _buildFilterChip('type', 'bug', context.t('feedback_bug')),
                  const SizedBox(width: 8),
                  _buildFilterChip('type', 'suggestion', context.t('feedback_suggestion')),
                  const SizedBox(width: 8),
                  _buildFilterChip('type', 'other', context.t('feedback_other')),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('status', 'open', context.t('status_open')),
                  const SizedBox(width: 8),
                  _buildFilterChip('status', 'replied', context.t('status_replied')),
                  const SizedBox(width: 8),
                  _buildFilterChip('status', 'closed', context.t('status_closed')),
                  const SizedBox(width: 8),
                  _buildFilterChip('status', 'all', context.t('filter_all')),
                ],
              ),
            ),
          ),
          const Divider(),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredFeedbacks.isEmpty
              ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(context.t('no_feedback_found')),
                ),
              )
              : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredFeedbacks.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final f = _filteredFeedbacks[index];
                  return _buildFeedbackCard(f);
                },
              ),
    );
  }

  Widget _buildFilterChip(String category, String value, String label) {
    final isSelected = category == 'type' ? _filterType == value : _filterStatus == value;
    final themeColor = ThemeService().primaryColor;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() {
          if (category == 'type') _filterType = value;
          else _filterStatus = value;
        });
      },
      selectedColor: themeColor.withValues(alpha: 0.2),
      checkmarkColor: themeColor,
      labelStyle: TextStyle(
        color: isSelected ? themeColor : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildFeedbackCard(FeedbackModel f) {
    final dateStr =
        f.createdAt != null ? f.createdAt!.toString().substring(0, 16) : '';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white70 : Colors.black54;

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FeedbackDetailPage(feedback: f),
          ),
        );
        _loadFeedbacks();
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getTypeColor(f.type).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          context.t('feedback_${f.type}').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: _getTypeColor(f.type),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: f.status),
                    ],
                  ),
                  Text(dateStr, style: TextStyle(fontSize: 12, color: subColor)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                f.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                f.content,
                style: TextStyle(fontSize: 14, color: subColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (f.attachmentUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 60,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: f.attachmentUrls.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          f.attachmentUrls[index],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
              ],
              if (f.subjectId != null || f.cardId != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  children: [
                    if (f.subjectId != null) ...[
                      Icon(Icons.folder_outlined, size: 14, color: subColor),
                      const SizedBox(width: 4),
                      Text(
                        'Sub: ${f.subjectName ?? f.subjectId!.substring(0, 8)}',
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),
                    ],
                    if (_isAdmin && f.cardId != null) ...[
                      const SizedBox(width: 12),
                      Icon(Icons.layers_outlined, size: 14, color: subColor),
                      const SizedBox(width: 4),
                      Text(
                        'Card: ${f.cardId!.substring(0, 8)}',
                        style: TextStyle(fontSize: 11, color: subColor),
                      ),
                    ],
                  ],
                ),
              ],
              if (_isAdmin) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: subColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${f.userName ?? 'Unknown'} (${f.userEmail ?? 'No Email'})',
                        style: TextStyle(fontSize: 11, color: subColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'bug':
        return Colors.red;
      case 'suggestion':
        return Colors.green;
      case 'other':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color = Colors.grey;
    if (status == 'open') color = Colors.green;
    else if (status == 'replied') color = Colors.blue;
    else if (status == 'closed') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
