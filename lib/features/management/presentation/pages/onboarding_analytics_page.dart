import 'package:flutter/material.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/data/models/onboarding_analytics_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/onboarding_analytics_service.dart';
import 'package:aliolo/data/services/theme_service.dart';
import 'package:aliolo/data/services/translation_service.dart';
import 'package:aliolo/core/utils/api_error.dart';

class OnboardingAnalyticsPage extends StatefulWidget {
  const OnboardingAnalyticsPage({super.key});

  @override
  State<OnboardingAnalyticsPage> createState() =>
      _OnboardingAnalyticsPageState();
}

class _OnboardingAnalyticsPageState extends State<OnboardingAnalyticsPage> {
  static const String _adminUserId = 'usyeo7d2yzf2773';

  final _authService = getIt<AuthService>();
  final _analyticsService = getIt<OnboardingAnalyticsService>();

  OnboardingAnalyticsPageModel _data = OnboardingAnalyticsPageModel.empty;
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isAdmin => _authService.currentUser?.serverId == _adminUserId;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _analyticsService.getOnboardingAnalytics();
      if (!mounted) return;
      setState(() {
        _data = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = formatApiErrorMessage(
          e,
          fallback: 'Could not load onboarding analytics. Please try again.',
        );
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime? value) {
    if (value == null) return 'Not available';
    return value
        .toLocal()
        .toIso8601String()
        .replaceFirst('T', ' ')
        .split('.')
        .first;
  }

  String _formatRate(double rate) => '${(rate * 100).toStringAsFixed(1)}%';

  Widget _buildSummaryCard(String label, String value, IconData icon) {
    final themeColor = ThemeService().primaryColor;
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: themeColor.withValues(alpha: 0.12),
              child: Icon(icon, size: 16, color: themeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildSummary() {
    final summary = _data.summary;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildSummaryCard(
          'Total sessions',
          '${summary.totalSessions}',
          Icons.analytics_outlined,
        ),
        _buildSummaryCard(
          'Linked emails',
          '${summary.linkedEmailSessions}',
          Icons.alternate_email,
        ),
        _buildSummaryCard(
          'Age selected',
          '${summary.ageSelectedSessions}',
          Icons.cake_outlined,
        ),
        _buildSummaryCard(
          'Pillar selected',
          '${summary.pillarSelectedSessions}',
          Icons.account_tree_outlined,
        ),
        _buildSummaryCard(
          'Final slide reached',
          '${summary.finalSlideSessions}',
          Icons.flag_outlined,
        ),
        _buildSummaryCard(
          'Unique emails',
          '${summary.uniqueEmails}',
          Icons.people_outline,
        ),
        _buildSummaryCard(
          'Avg last slide',
          summary.averageLastSlideIndex == null
              ? 'Not available'
              : summary.averageLastSlideIndex!.toStringAsFixed(2),
          Icons.percent_outlined,
        ),
        _buildSummaryCard(
          'Completion rate',
          _formatRate(summary.completionRate),
          Icons.check_circle_outline,
        ),
      ],
    );
  }

  Widget _buildBreakdownCard() {
    return Column(
      children: [
        _buildSection(
          'Age breakdown',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _data.ageBreakdown.isEmpty
                    ? [Text(context.t('no_age_data_yet'))]
                    : _data.ageBreakdown
                        .map(
                          (row) => _buildChip(row.ageRange, '${row.sessions}'),
                        )
                        .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _buildSection(
          'Pillar breakdown',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _data.pillarBreakdown.isEmpty
                    ? [Text(context.t('no_pillar_data_yet'))]
                    : _data.pillarBreakdown
                        .map(
                          (row) =>
                              _buildChip(row.pillarName, '${row.sessions}'),
                        )
                        .toList(),
          ),
        ),
        const SizedBox(height: 12),
        _buildSection(
          'Slide breakdown',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _data.slideBreakdown.isEmpty
                    ? [Text(context.t('no_slide_data_yet'))]
                    : _data.slideBreakdown
                        .map(
                          (row) => _buildChip(
                            row.lastSlideIndex == null
                                ? 'Not set'
                                : 'Slide ${row.lastSlideIndex}',
                            '${row.sessions}',
                          ),
                        )
                        .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSessionsTable() {
    if (_data.recentSessions.isEmpty) {
      return Text(context.t('no_onboarding_sessions_yet'));
    }

    final rows =
        _data.recentSessions
            .map(
              (row) => DataRow(
                cells: [
                  DataCell(SelectableText(row.sessionId)),
                  DataCell(
                    SelectableText(row.userEmail ?? context.t('not_set')),
                  ),
                  DataCell(Text(row.ageRange ?? context.t('not_set'))),
                  DataCell(
                    Text(
                      row.pillarName ??
                          (row.pillarId?.toString() ?? context.t('not_set')),
                    ),
                  ),
                  DataCell(
                    Text(
                      row.lastSlideIndex?.toString() ?? context.t('not_set'),
                    ),
                  ),
                  DataCell(Text(_formatDate(row.updatedAt))),
                ],
              ),
            )
            .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(context.t('session'))),
          DataColumn(label: Text(context.t('email'))),
          DataColumn(label: Text(context.t('age'))),
          DataColumn(label: Text(context.t('pillar'))),
          DataColumn(label: Text(context.t('last_slide'))),
          DataColumn(label: Text(context.t('updated'))),
        ],
        rows: rows,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ThemeService().primaryColor;
    const appBarColor = Colors.white;

    return AlioloScrollablePage(
      title: Text(
        context.t('onboarding_analytics'),
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
          onPressed: _loadAnalytics,
        ),
      ],
      body:
          !_isAdmin
              ? Padding(
                padding: const EdgeInsets.all(32),
                child: Center(child: Text(context.t('not_available'))),
              )
              : _isLoading
              ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
              : _errorMessage != null
              ? Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Text(_errorMessage!),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _loadAnalytics,
                      child: Text(context.t('retry')),
                    ),
                  ],
                ),
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  _buildSummary(),
                  const SizedBox(height: 12),
                  _buildBreakdownCard(),
                  const SizedBox(height: 12),
                  _buildSection('Recent sessions', _buildRecentSessionsTable()),
                ],
              ),
    );
  }
}
