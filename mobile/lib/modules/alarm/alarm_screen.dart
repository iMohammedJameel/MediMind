import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../l10n/app_strings.dart';
import '../../models/dose_event_model.dart';
import '../../models/medication_model.dart';
import '../../services/alarm_service.dart';
import '../../shared/styles/colors.dart';
import '../../shared/components/components.dart';
import '../../shared/network/local/cache_helper.dart';
import '../../shared/utils/formatters.dart';
import '../../shared/utils/medication_icons.dart';
import 'cubit/alarm_cubit.dart';
import 'cubit/alarm_states.dart';

/// Full-screen medication alarm — reachable straight from a notification tap.
/// Elderly-first: huge text, one dominant action, everything tappable in < 5s.
///
/// When this screen opens, [AlarmService] starts a looping alarm sound on the
/// Android alarm audio stream (plays even in silent/DND mode) plus periodic
/// vibration. The sound stops only when the patient taps "Taken", "Snooze", or
/// "Skip".
class AlarmScreen extends StatelessWidget {
  final DoseEventModel? dose;
  const AlarmScreen({super.key, this.dose});

  @override
  Widget build(BuildContext context) {
    if (dose != null) {
      return BlocProvider(
        create: (_) => AlarmCubit(dose!),
        child: const _AlarmView(),
      );
    }
    // Cold start: resolve the dose by id before showing the alarm.
    return FutureBuilder<DoseEventModel?>(
      future: AlarmCubit.resolveDose(
          GoRouter.of(context).state.pathParameters['doseId'] ?? ''),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final resolved = snap.data;
        if (resolved == null) {
          // Not today's dose anymore — a friendly dead end with a way out
          // (previously a BLANK screen the user could not leave).
          return Scaffold(
            appBar: AppBar(title: const Text('MediMind')),
            body: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.alarm_off_rounded,
                        size: 64, color: AppColors.textSecondary),
                    const SizedBox(height: 16),
                    Text(
                      context.tr('alarm.notAvailable'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.go(CacheHelper.isLoggedIn
                          ? homeForRole(CacheHelper.getRole())
                          : Routes.login),
                      icon: const Icon(Icons.home_outlined),
                      label: Text(context.tr('common.backHome')),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return BlocProvider(
          create: (_) => AlarmCubit(resolved),
          child: const _AlarmView(),
        );
      },
    );
  }
}

class _AlarmView extends StatefulWidget {
  const _AlarmView();

  @override
  State<_AlarmView> createState() => _AlarmViewState();
}

class _AlarmViewState extends State<_AlarmView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  int _snoozeMinutes = 5;

  @override
  void initState() {
    super.initState();

    // Start the alarm sound + vibration
    AlarmService.instance.startAlarm();

    // Pulsing animation for the medication icon
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    // Safety net: stop alarm if the screen is popped without user action
    AlarmService.instance.stopAlarm();
    super.dispose();
  }

  Future<void> _stopAlarmAndRun(VoidCallback action) async {
    HapticFeedback.mediumImpact();
    await AlarmService.instance.stopAlarm();
    action();
  }

  MedicationModel? _lookupCachedMed(String medicationId) {
    try {
      final raw = CacheHelper.getString(CacheHelper.cachedMedicationsKey);
      if (raw == null) return null;
      final strings = (jsonDecode(raw) as List).cast<String>();
      for (final s in strings) {
        final med = MedicationModel.fromJson(jsonDecode(s));
        if (med.id == medicationId) return med;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AlarmCubit, AlarmStates>(
      listener: (context, state) {
        if (state is AlarmDone) {
          if (state.dose.isTaken) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('alarm.recorded'))),
            );
          } else if (state.dose.isPending || state.dose.isLate) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('today.snoozed'))),
            );
          }
          context.go(Routes.patientHome);
        } else if (state is AlarmError) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.trv(state.message))));
        }
      },
      child: BlocBuilder<AlarmCubit, AlarmStates>(
        builder: (context, state) {
          final ready = state is AlarmReady ? state : null;
          final busy = state is AlarmActionLoading;
          final dose = (ready ?? (state is AlarmActionLoading ? state.previous : null))
                  ?.dose ??
              (state is AlarmDone ? state.dose : null) ??
              // Error keeps the dose so the buttons stay usable for a RETRY
              // (an error used to leave the screen on an endless spinner).
              (state is AlarmError ? state.dose : null);
          if (dose == null) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }

          return Scaffold(
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  // Fill the viewport when there is room (Spacers push the
                  // action buttons to the bottom) and scroll when there is
                  // not — elderly text scales up to ~2.3x must never
                  // overflow the alarm screen.
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Spacer(),
                            // Pulsing medication icon — visual cue that alarm is active
                            ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.danger.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.danger
                                          .withValues(alpha: 0.3),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.medication,
                                    size: 64, color: AppColors.danger),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Alarm icon indicator
                            const Icon(Icons.alarm_on,
                                size: 28, color: AppColors.danger),
                            const SizedBox(height: 8),
                            Text(
                              context.tr('alarm.title'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            GlassCard(
                              radius: 26,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 20),
                              child: Column(
                                children: [
                                  Text(
                                    dose.medicationName,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .displaySmall
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${context.tr('alarm.scheduled')} — ${dose.timeLabel}',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall,
                                  ),
                                  Builder(
                                    builder: (context) {
                                      final med = _lookupCachedMed(
                                          dose.medicationId);
                                      final mealKey =
                                          MedicationIcons.mealLabelKey(
                                              med?.relationToMeals);
                                      final noteText =
                                          (med?.notes ?? '').trim();
                                      final tip = [
                                        if (mealKey != null)
                                          context.tr(mealKey),
                                        if (noteText.isNotEmpty) noteText,
                                      ].join(' • ');
                                      if (tip.isEmpty) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(top: 10),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withValues(alpha: .10),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            tip,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // ── Taken ──
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minWidth: double.infinity,
                                minHeight: 72,
                              ),
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(72),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  backgroundColor: AppColors.success,
                                  textStyle: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800),
                                ),
                                onPressed: busy
                                    ? null
                                    : () => _stopAlarmAndRun(() => context
                                        .read<AlarmCubit>()
                                        .confirmDose()),
                                icon: const Icon(Icons.check_circle, size: 36),
                                label: Text(context.tr('alarm.take')),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // ── Snooze ──
                            Builder(
                              builder: (context) {
                                final lang = context.lang;
                                String fmtMin(int m) =>
                                    AppFormatters.digitsForLocale('$m',
                                        locale: lang);
                                return Column(
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      alignment: WrapAlignment.center,
                                      children: [5, 15, 30]
                                          .map((m) => ChoiceChip(
                                                label: Text(
                                                    '${fmtMin(m)} ${context.tr('alarm.minShort')}'),
                                                selected: _snoozeMinutes == m,
                                                onSelected: busy
                                                    ? null
                                                    : (_) => setState(
                                                        () => _snoozeMinutes = m),
                                              ))
                                          .toList(),
                                    ),
                                    const SizedBox(height: 8),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        minWidth: double.infinity,
                                        minHeight: 60,
                                      ),
                                      child: OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          minimumSize:
                                              const Size.fromHeight(60),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 12),
                                          textStyle: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700),
                                        ),
                                        onPressed: busy
                                            ? null
                                            : () => _stopAlarmAndRun(() =>
                                                context
                                                    .read<AlarmCubit>()
                                                    .snooze(
                                                        minutes:
                                                            _snoozeMinutes)),
                                        icon: const Icon(Icons.snooze, size: 28),
                                        label: Text(_snoozeMinutes == 5
                                            ? context.tr('alarm.snooze')
                                            : context
                                                .tr('alarm.snoozeCustom')
                                                .replaceAll(
                                                    '{min}',
                                                    fmtMin(_snoozeMinutes))),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            // ── Skip ──
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => _stopAlarmAndRun(() =>
                                      context.read<AlarmCubit>().skipDose()),
                              child: Text(context.tr('alarm.skip'),
                                  style: const TextStyle(fontSize: 16)),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
