import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../services/progress_analytics_service.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late Future<ProgressAnalytics> _analyticsFuture;

  @override
  void initState() {
    super.initState();
    _analyticsFuture = ProgressAnalyticsService.load();
  }

  Future<void> _refresh() async {
    final next = ProgressAnalyticsService.load();
    setState(() => _analyticsFuture = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _refresh(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<ProgressAnalytics>(
        future: _analyticsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load progress data. Pull to refresh.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data;
          if (data == null) {
            return const Center(child: Text('No progress data yet.'));
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _HeroSummary(data: data),
                const SizedBox(height: 16),
                _SummaryGrid(data: data),
                const SizedBox(height: 16),
                _SevenDayCard(data: data),
                const SizedBox(height: 16),
                _RecentSessionsCard(data: data),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroSummary extends StatelessWidget {
  const _HeroSummary({required this.data});

  final ProgressAnalytics data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.primary, Color(0xFF4C1D95)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Learning Momentum',
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${(data.accuracy * 100).toStringAsFixed(1)}% overall accuracy',
                  style: textTheme.titleLarge?.copyWith(
                    color: scheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${data.answeredQuestionCount} answers evaluated',
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.onPrimary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.trending_up_rounded, color: scheme.onPrimary),
          ),
        ],
      ),
    );
  }
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.data});

  final ProgressAnalytics data;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.45,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      children: [
        _SummaryTile(label: 'Materials', value: data.materialCount.toString()),
        _SummaryTile(
          label: 'Study sessions',
          value: data.studySessionCount.toString(),
        ),
        _SummaryTile(
          label: 'Accuracy',
          value: '${(data.accuracy * 100).toStringAsFixed(1)}%',
        ),
        _SummaryTile(
          label: 'Current streak',
          value:
              '${data.currentStreakDays} day${data.currentStreakDays == 1 ? '' : 's'}',
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SevenDayCard extends StatelessWidget {
  const _SevenDayCard({required this.data});

  final ProgressAnalytics data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Last 7 days',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            for (final day in data.lastSevenDays)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        DateFormat.E().format(day.day),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _progressForDay(
                          data.lastSevenDays,
                          day.sessions,
                        ),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(6),
                        backgroundColor: scheme.surfaceContainerHigh,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 42,
                      child: Text(
                        '${day.sessions}',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
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

  double _progressForDay(List<DailyProgress> values, int current) {
    final max = values.fold<int>(0, (prev, item) {
      return item.sessions > prev ? item.sessions : prev;
    });
    if (max <= 0) return 0;
    return current / max;
  }
}

class _RecentSessionsCard extends StatelessWidget {
  const _RecentSessionsCard({required this.data});

  final ProgressAnalytics data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent sessions',
              style: theme.textTheme.titleMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (data.recentSessions.isEmpty)
              Text(
                'No study sessions yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              for (final session in data.recentSessions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.history_rounded, color: scheme.primary),
                  title: Text(
                    session.materialTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat.yMMMd().add_Hm().format(session.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: Text(
                    '${(session.accuracy * 100).toStringAsFixed(0)}%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
