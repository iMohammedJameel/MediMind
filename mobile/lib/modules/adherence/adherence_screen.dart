import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../l10n/app_strings.dart';
import '../../models/dose_event_model.dart';
import '../../services/adherence_report_service.dart';
import '../../shared/components/components.dart';
import '../../shared/styles/colors.dart';
import '../../shared/utils/formatters.dart';
import 'cubit/adherence_cubit.dart';
import 'cubit/adherence_states.dart';

/// Adherence tracker: today / week / month with summary + breakdown chart.
class AdherenceScreen extends StatelessWidget {
  const AdherenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AdherenceCubit()..load(),
      child: const _AdherenceView(),
    );
  }
}

class _AdherenceView extends StatelessWidget {
  const _AdherenceView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdherenceCubit, AdherenceStates>(
      builder: (context, state) {
        final cubit = context.read<AdherenceCubit>();
        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('adherence.title')),
            actions: [
              if (state is AdherenceLoaded)
                IconButton(
                  tooltip: context.tr('adherence.share'),
                  icon: const Icon(Icons.ios_share),
                  onPressed: () => _openShareSheet(context, state),
                ),
            ],
          ),
          bottomNavigationBar: const PatientBottomNav(currentIndex: 2),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SegmentedButton<AdherenceRange>(
                  segments: [
                    ButtonSegment(
                        value: AdherenceRange.today,
                        label: Text(context.tr('adherence.today'))),
                    ButtonSegment(
                        value: AdherenceRange.week,
                        label: Text(context.tr('adherence.week'))),
                    ButtonSegment(
                        value: AdherenceRange.month,
                        label: Text(context.tr('adherence.month'))),
                  ],
                  selected: {cubit.range},
                  onSelectionChanged: (s) => cubit.setRange(s.first),
                ),
              ),
              Expanded(
                child: state is AdherenceLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state is AdherenceError
                        ? ErrorWithRetry(
                            message: context.trv(state.message),
                            onRetry: () => cubit.load())
                        : state is AdherenceLoaded
                            ? _content(context, state.summary, state.range,
                                state.doses, state.streak)
                            : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openShareSheet(BuildContext context, AdherenceLoaded state) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined,
                    color: AppColors.primary),
                title: Text(context.tr('adherence.sharePdf')),
                subtitle: Text(context.tr('adherence.sharePdfHint')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  AdherenceReportService.sharePdf(context, state);
                },
              ),
              ListTile(
                leading: const Icon(Icons.text_snippet_outlined,
                    color: AppColors.teal),
                title: Text(context.tr('adherence.shareText')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  AdherenceReportService.shareText(context, state);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, AdherenceSummary s,
      AdherenceRange range, List<DoseEventModel> doses, int streak) {
    final milestone = AdherenceSummary.streakMilestone(streak);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _streakCard(context, streak, milestone),
          const SizedBox(height: 12),
          GlassCard(
            child: Row(
              children: [
                AdherenceRing(percent: s.percentDueSoFar(doses)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _stat(
                          context,
                          range == AdherenceRange.today
                              ? context.tr('adherence.takenToday')
                              : context.tr('adherence.taken'),
                          '${s.taken}',
                          AppColors.success),
                      const SizedBox(height: 8),
                      _stat(context, context.tr('adherence.missed'),
                          '${s.missed}', AppColors.danger),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (range != AdherenceRange.today && doses.isNotEmpty) ...[
            const SizedBox(height: 14),
            _dailyHeatmapCard(context, doses, range),
          ],
          const SizedBox(height: 18),
          SizedBox(
            height: 250,
            child: GlassCard(
              padding: const EdgeInsets.fromLTRB(14, 24, 14, 14),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (s.total).toDouble() + 1,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.35),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.primaryDark,
                      tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                          BarTooltipItem(
                        '${rod.toY.round()}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  barGroups: [
                    _bar(0, s.taken.toDouble(), AppColors.success),
                    _bar(1, s.missed.toDouble(), AppColors.danger),
                    _bar(2, s.late.toDouble(), AppColors.warning),
                    _bar(3, s.pending.toDouble(), AppColors.info),
                    _bar(4, s.skipped.toDouble(), AppColors.textSecondary),
                  ],
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (value, meta) => FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: switch (value.toInt()) {
                              0 => Text(
                                  '${context.tr('adherence.taken')} (${s.taken})'),
                              1 => Text(
                                  '${context.tr('adherence.missed')} (${s.missed})'),
                              2 => Text(
                                  '${context.tr('adherence.late')} (${s.late})'),
                              3 => Text(
                                  '${context.tr('adherence.upcoming')} (${s.pending})'),
                              4 => Text(
                                  '${context.tr('adherence.skipped')} (${s.skipped})'),
                              _ => const Text(''),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dailyHeatmapCard(
      BuildContext context, List<DoseEventModel> doses, AdherenceRange range) {
    final daysCount = range == AdherenceRange.week ? 7 : 30;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDay = <DateTime, List<DoseEventModel>>{};
    for (final d in doses) {
      final key = DateTime(
          d.scheduledFor.year, d.scheduledFor.month, d.scheduledFor.day);
      byDay.putIfAbsent(key, () => []).add(d);
    }

    Color colorForDay(DateTime day) {
      final list = byDay[day];
      if (list == null || list.isEmpty) {
        return Theme.of(context).colorScheme.surfaceContainerHighest;
      }
      final taken = list.where((d) => d.isTaken).length;
      final missed = list.where((d) => d.isMissed).length;
      if (taken == list.length) return AppColors.success;
      if (missed > 0 && taken == 0) return AppColors.danger;
      return AppColors.warning;
    }

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('adherence.dailyCalendar'),
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = daysCount - 1; i >= 0; i--)
                Builder(
                  builder: (_) {
                    final day = today.subtract(Duration(days: i));
                    final c = colorForDay(day);
                    return Tooltip(
                      message: '${day.day}/${day.month}',
                      child: Container(
                        width: range == AdherenceRange.week ? 32 : 20,
                        height: range == AdherenceRange.week ? 32 : 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: c.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: range == AdherenceRange.week
                            ? Text(
                                '${day.day}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _legendDot(context, AppColors.success,
                  context.tr('adherence.legendFull')),
              _legendDot(context, AppColors.warning,
                  context.tr('adherence.legendPartial')),
              _legendDot(context, AppColors.danger,
                  context.tr('adherence.legendMissed')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      );

  BarChartGroupData _bar(int x, double y, Color color) => BarChartGroupData(
        x: x,
        barRods: [
          BarChartRodData(
            toY: y,
            color: color,
            width: 22,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );

  Widget _streakCard(
      BuildContext context, int streak, (int, String)? milestone) {
    final active = streak > 0;
    return GlassCard(
      tint: (active ? AppColors.warning : AppColors.info).withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(
              active ? Icons.local_fire_department_rounded : Icons.flag_outlined,
              size: 42,
              color: active ? AppColors.warning : AppColors.info,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        active
                            ? AppFormatters.digitsForLocale('$streak',
                                locale: context.lang)
                            : '—',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: active ? AppColors.warning : AppColors.info),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${context.tr('streak.title')} — ${context.tr('streak.days')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    milestone != null
                        ? context.tr(milestone.$2)
                        : (active
                            ? context.tr('streak.keepGoing')
                            : context.tr('streak.start')),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: milestone != null
                            ? AppColors.warning
                            : AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      );
}
