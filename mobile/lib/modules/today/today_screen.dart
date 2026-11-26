import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../l10n/app_strings.dart';
import '../../models/dose_event_model.dart';
import '../../services/local_notifications_service.dart';
import '../../shared/components/components.dart';
import '../../shared/network/local/cache_helper.dart';
import '../../shared/styles/colors.dart';
import 'cubit/today_cubit.dart';
import 'cubit/today_states.dart';
import 'widgets/today_dose_cards.dart';
import 'widgets/today_header.dart';
import 'widgets/today_overview_cards.dart';

/// Patient home — daily progress, next dose, PRN quick log, and schedule.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (context) => TodayCubit()..loadSchedule(),
        child: const _TodayView(),
      );
}

class _TodayView extends StatelessWidget {
  const _TodayView();

  DoseEventModel? _nextPending(List<DoseEventModel> doses) {
    final pending = doses.where((d) => d.isPending || d.isLate).toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return pending.isEmpty ? null : pending.first;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TodayCubit, TodayStates>(
      listener: (context, state) {
        if (state is DoseActionError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.trv(state.message))),
          );
        } else if (state is AsNeededLogged) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.tr('today.asNeededLogged')),
              backgroundColor: AppColors.success,
            ),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<TodayCubit>();
        final doses = cubit.doses;
        final summary = AdherenceSummary.fromDoses(doses);
        final next = _nextPending(doses);

        return Scaffold(
          backgroundColor: Colors.transparent,
          bottomNavigationBar: const PatientBottomNav(currentIndex: 0),
          body: SafeArea(
            top: true,
            child: state is TodayLoading
                ? ListView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                    children: const [
                      TodayHeader(),
                      SizedBox(height: 18),
                      DoseSkeleton(),
                      DoseSkeleton(),
                    ],
                  )
                : state is TodayError
                    ? ErrorWithRetry(
                        message: context.trv(state.message),
                        onRetry: () => cubit.loadSchedule(),
                      )
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () => cubit.loadSchedule(),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
                          children: [
                            const TodayHeader(),
                            const SizedBox(height: 14),
                            const _ExactAlarmPermissionBanner(),
                            if (state is TodayLoaded && state.fromCache)
                              _OfflineNotice(text: context.tr('today.offline')),
                            TodayProgressCard(summary: summary, doses: doses),
                            const SizedBox(height: 14),
                            NextDoseCard(
                              next: next,
                              onTap: next == null
                                  ? null
                                  : () async {
                                      await context.push(
                                          Routes.alarm(next.id),
                                          extra: next);
                                      if (context.mounted) {
                                        cubit.loadSchedule();
                                      }
                                    },
                            ),
                            const SizedBox(height: 16),
                            TodayQuickActions(
                              scanLabel: context.tr('today.scan'),
                              addLabel: context.tr('today.addManual'),
                              onScan: () => context.push(Routes.scan),
                              onAdd: () => context.push(Routes.medications),
                            ),
                            const SizedBox(height: 22),
                            if (cubit.asNeededMeds.isNotEmpty) ...[
                              _SectionHeading(
                                title: context.tr('today.asNeededTitle'),
                                trailing: '',
                              ),
                              const SizedBox(height: 10),
                              ...cubit.asNeededMeds.map((med) => Padding(
                                    padding: const EdgeInsets.only(bottom: 11),
                                    child: AsNeededDoseCard(
                                      med: med,
                                      busy: state is AsNeededLogging &&
                                          state.medicationId == med.id,
                                      onLog: () => cubit.logAsNeededDose(med),
                                    ),
                                  )),
                              const SizedBox(height: 12),
                            ],
                            _SectionHeading(
                              title: context.tr('today.title'),
                              trailing:
                                  '${doses.length} ${context.tr('today.scheduleCount')}',
                            ),
                            const SizedBox(height: 10),
                            if (doses.isEmpty)
                              const _EmptyScheduleGlass()
                            else
                              ..._buildGroupedSchedule(
                                context,
                                cubit,
                                state,
                                doses,
                              ),
                          ],
                        ),
                      ),
          ),
        );
      },
    );
  }

  List<Widget> _buildGroupedSchedule(
    BuildContext context,
    TodayCubit cubit,
    TodayStates state,
    List<DoseEventModel> doses,
  ) {
    final sorted = [...doses]
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    final morning = <DoseEventModel>[];
    final afternoon = <DoseEventModel>[];
    final evening = <DoseEventModel>[];
    for (final d in sorted) {
      final h = d.scheduledFor.hour;
      if (h < 12) {
        morning.add(d);
      } else if (h < 17) {
        afternoon.add(d);
      } else {
        evening.add(d);
      }
    }

    Widget groupHeader(String label, IconData icon, Color tint) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 17, color: tint),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        );

    Widget buildCard(DoseEventModel dose) => DoseCard(
          key: ValueKey('${dose.id}-${dose.status}'),
          dose: dose,
          medication: cubit.medsById[dose.medicationId],
          busy: state is DoseActionLoading && state.doseEventId == dose.id,
          onTaken: () => cubit.confirmDose(dose.id),
          onSkip: () => _confirmSkipSheet(context, cubit, dose),
          onSnooze: () {
            cubit.snooze(dose);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('today.snoozed'))),
            );
          },
        );

    return [
      if (morning.isNotEmpty) ...[
        groupHeader(
          context.tr('today.periodMorning'),
          Icons.wb_sunny_outlined,
          AppColors.warning,
        ),
        ...morning.map(buildCard),
      ],
      if (afternoon.isNotEmpty) ...[
        groupHeader(
          context.tr('today.periodAfternoon'),
          Icons.light_mode_outlined,
          AppColors.teal,
        ),
        ...afternoon.map(buildCard),
      ],
      if (evening.isNotEmpty) ...[
        groupHeader(
          context.tr('today.periodEvening'),
          Icons.nights_stay_outlined,
          AppColors.info,
        ),
        ...evening.map(buildCard),
      ],
    ];
  }

  /// Safety net for elderly users: confirms before skipping and offers a
  /// one-tap 15-minute snooze rescue instead.
  void _confirmSkipSheet(
    BuildContext context,
    TodayCubit cubit,
    DoseEventModel dose,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                sheetContext.tr('today.skipConfirmTitle'),
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                sheetContext
                    .tr('today.skipConfirmBody')
                    .replaceAll('{med}', dose.medicationName),
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(sheetContext);
                  cubit.snooze(dose, minutes: 15);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('today.snoozed'))),
                  );
                },
                icon: const Icon(Icons.snooze_rounded),
                label: Text(sheetContext.tr('today.snooze15Instead')),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pop(sheetContext);
                  cubit.skipDose(dose.id);
                },
                icon: const Icon(Icons.skip_next_rounded),
                label: Text(sheetContext.tr('today.skipDose')),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(sheetContext.tr('common.cancel')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String trailing;
  const _SectionHeading({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.brandText,
              ),
            ),
          ),
          if (trailing.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                trailing,
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white60
                      : AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ],
      );
}

class _OfflineNotice extends StatelessWidget {
  final String text;
  const _OfflineNotice({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassCard(
          margin: EdgeInsets.zero,
          radius: 16,
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: AppColors.amberAccent),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 13))),
            ],
          ),
        ),
      );
}

class _EmptyScheduleGlass extends StatelessWidget {
  const _EmptyScheduleGlass();

  @override
  Widget build(BuildContext context) => GlassCard(
        margin: EdgeInsets.zero,
        radius: 24,
        child: Column(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 34,
                color: AppColors.secondaryText.withValues(alpha: .8)),
            const SizedBox(height: 8),
            Text(
              context.tr('home.noDoses'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.tonalIcon(
              onPressed: () => context.push(Routes.medications),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.tr('today.emptyAddCta')),
            ),
          ],
        ),
      );
}

class _ExactAlarmPermissionBanner extends StatefulWidget {
  const _ExactAlarmPermissionBanner();

  @override
  State<_ExactAlarmPermissionBanner> createState() =>
      _ExactAlarmPermissionBannerState();
}

class _ExactAlarmPermissionBannerState extends State<_ExactAlarmPermissionBanner>
    with WidgetsBindingObserver {
  bool _needsPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    if (!CacheHelper.getNotificationsEnabled()) {
      if (mounted && _needsPermission) setState(() => _needsPermission = false);
      return;
    }
    final needs =
        await LocalNotificationsService.shouldPromptForExactAlarmPermission();
    if (mounted && needs != _needsPermission) {
      setState(() => _needsPermission = needs);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsPermission) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        margin: EdgeInsets.zero,
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.alarm_on_rounded, color: AppColors.amberAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.tr('alarm.exactPermBanner'),
                style: const TextStyle(fontSize: 12.5, height: 1.3),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: LocalNotificationsService.openExactAlarmSettings,
              child: Text(context.tr('alarm.exactPermAction')),
            ),
          ],
        ),
      ),
    );
  }
}
