import 'package:flutter/material.dart';
import 'package:aliolo/core/di/service_locator.dart';
import 'package:aliolo/core/widgets/aliolo_scrollable_page.dart';
import 'package:aliolo/data/models/subject_usage_model.dart';
import 'package:aliolo/data/services/auth_service.dart';
import 'package:aliolo/data/services/subject_usage_service.dart';
import 'package:aliolo/data/services/theme_service.dart';

class SubjectUsagePage extends StatefulWidget {
  const SubjectUsagePage({super.key});

  @override
  State<SubjectUsagePage> createState() => _SubjectUsagePageState();
}

class _SubjectUsagePageState extends State<SubjectUsagePage> {
  static const String _adminUserId = 'usyeo7d2yzf2773';

  final _authService = getIt<AuthService>();
  final _subjectUsageService = getIt<SubjectUsageService>();

  List<SubjectUsageModel> _rows = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedPeriod = 'all';

  bool get _isAdmin => _authService.currentUser?.serverId == _adminUserId;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rows = await _subjectUsageService.getSubjectUsage(
        period: _selectedPeriod,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatRate(double rate) => '${(rate * 100).round()}%';

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildUsageCard(SubjectUsageModel row, int index) {
    final themeColor = ThemeService().primaryColor;
    final location = [
      if (row.pillarName?.isNotEmpty == true) row.pillarName!,
      if (row.folderName?.isNotEmpty == true) row.folderName!,
    ].join(' / ');

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: themeColor.withValues(alpha: 0.12),
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.subjectName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (location.isNotEmpty)
                        Text(
                          location,
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _buildMetric('Starts', '${row.totalStarted}'),
                _buildMetric('Completed', '${row.totalCompleted}'),
                _buildMetric('Completion', _formatRate(row.completionRate)),
                _buildMetric(
                  'Learn',
                  '${row.learnStarted}/${row.learnCompleted}',
                ),
                _buildMetric('Test', '${row.testStarted}/${row.testCompleted}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeColor = ThemeService().primaryColor;
    const appBarColor = Colors.white;

    return AlioloScrollablePage(
      title: const Text(
        'Subject Usage',
        style: TextStyle(color: appBarColor, fontWeight: FontWeight.bold),
      ),
      appBarColor: themeColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: appBarColor),
          onPressed: () => Navigator.pop(context),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: appBarColor),
          onPressed: _loadUsage,
        ),
      ],
      body:
          !_isAdmin
              ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Not available')),
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
                      onPressed: _loadUsage,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : _rows.isEmpty
              ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No usage data yet')),
              )
              : Column(
                children: [
                  const SizedBox(height: 12),
                  _buildPeriodSelector(),
                  const SizedBox(height: 12),
                  for (var i = 0; i < _rows.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildUsageCard(_rows[i], i),
                    ),
                ],
              ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedPeriod,
          items: const [
            DropdownMenuItem(value: '1m', child: Text('Last Month')),
            DropdownMenuItem(value: '3m', child: Text('Last 3 Months')),
            DropdownMenuItem(value: '6m', child: Text('Last 6 Months')),
            DropdownMenuItem(value: 'all', child: Text('All Time')),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedPeriod = val);
              _loadUsage();
            }
          },
        ),
      ),
    );
  }
}
