import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/dose_event_model.dart';
import '../../../models/medication_model.dart';
import '../../../shared/components/components.dart';
import '../../../shared/styles/colors.dart';
import '../../../shared/utils/medication_icons.dart';

/// Scheduled dose card with dosage-form icon, meal instructions, status chip,
/// and Taken / Snooze / Skip actions.
class DoseCard extends StatelessWidget {
  final DoseEventModel dose;
  final MedicationModel? medication;
  final bool busy;
  final VoidCallback onTaken;
  final VoidCallback onSkip;
  final VoidCallback onSnooze;

  const DoseCard({
    super.key,
    required this.dose,
    this.medication,
    required this.busy,
    required this.onTaken,
    required this.onSkip,
    required this.onSnooze,
  });

  (Color, String, IconData) _status(BuildContext context) =>
      switch (dose.status) {
        'TAKEN' => (
            AppColors.success,
            context.tr('today.takenDone'),
            Icons.check_circle_rounded,
          ),
        'MISSED' => (
            AppColors.danger,
            context.tr('today.missed'),
            Icons.error_rounded,
          ),
        'LATE' => (
            AppColors.warning,
            context.tr('today.late'),
            Icons.warning_amber_rounded,
          ),
        'SKIPPED' => (
            AppColors.textSecondary,
            context.tr('today.skipped'),
            Icons.skip_next_rounded,
          ),
        _ => (
            const Color(0xFF5B8877),
            context.tr('today.pending'),
            Icons.schedule_rounded,
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusLabel, statusIcon) = _status(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mealKey = MedicationIcons.mealLabelKey(medication?.relationToMeals);
    final noteText = (medication?.notes ?? '').trim();
    final guidance = [
      if (mealKey != null) context.tr(mealKey),
      if (noteText.isNotEmpty) noteText,
    ].join(' • ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GlassCard(
        margin: EdgeInsets.zero,
        radius: 21,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: dark
                        ? AppColors.tealDark.withValues(alpha: .18)
                        : const Color(0xFFDCEFE4).withValues(alpha: .85),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(MedicationIcons.forForm(medication?.formType),
                      color: dark ? const Color(0xFF5EEAD4) : AppColors.primary,
                      size: 23),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dose.medicationName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: dark ? Colors.white : AppColors.brandText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(statusIcon, size: 14, color: statusColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: dark
                        ? Colors.white.withValues(alpha: .10)
                        : Colors.white.withValues(alpha: .55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    dose.timeLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: dark ? const Color(0xFF5EEAD4) : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            if (guidance.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (dark ? AppColors.tealDark : AppColors.primary)
                      .withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: 14,
                      color:
                          dark ? const Color(0xFF5EEAD4) : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        guidance,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: dark ? Colors.white70 : AppColors.brandText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: AlignmentDirectional.topStart,
              child: (dose.isPending || dose.isLate)
                  ? Padding(
                      padding: const EdgeInsets.only(top: 13),
                      child: busy
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                    child: _TakenButton(onPressed: onTaken)),
                                const SizedBox(width: 8),
                                _SmallAction(
                                  icon: Icons.snooze_rounded,
                                  tooltip: context.tr('today.snooze'),
                                  onTap: onSnooze,
                                ),
                                const SizedBox(width: 6),
                                _SmallAction(
                                  icon: Icons.skip_next_rounded,
                                  tooltip: context.tr('today.skipDose'),
                                  onTap: onSkip,
                                ),
                              ],
                            ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _SmallAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: dark
            ? Colors.white.withValues(alpha: .10)
            : Colors.white.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon,
                color: dark ? const Color(0xFF5EEAD4) : AppColors.primary),
          ),
        ),
      ),
    );
  }
}

/// Quick-log card for an as-needed (PRN) medication.
class AsNeededDoseCard extends StatelessWidget {
  final MedicationModel med;
  final bool busy;
  final VoidCallback onLog;

  const AsNeededDoseCard({
    super.key,
    required this.med,
    required this.busy,
    required this.onLog,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      margin: EdgeInsets.zero,
      radius: 21,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: dark
                      ? const Color(0xFF9A6B2F).withValues(alpha: .28)
                      : const Color(0xFFF3E8D3).withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.emergency_outlined,
                  color: dark
                      ? const Color(0xFFFBBF24)
                      : const Color(0xFF9A6B2F),
                  size: 23,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : AppColors.brandText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      context.tr('today.asNeededHint'),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            dark ? Colors.white70 : AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                textStyle: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
                minimumSize: const Size(64, 48),
              ),
              onPressed: busy ? null : onLog,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.add_task_rounded, size: 18),
              label: Text(
                context.tr('today.logNow'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TakenButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _TakenButton({required this.onPressed});

  @override
  State<_TakenButton> createState() => _TakenButtonState();
}

class _TakenButtonState extends State<_TakenButton> {
  bool _pressed = false;
  bool _done = false;

  void _handleTap() {
    if (_done) return;
    HapticFeedback.mediumImpact();
    setState(() => _done = true);
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) widget.onPressed();
    });
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _done ? 1.02 : (_pressed ? .96 : 1),
          duration: const Duration(milliseconds: 180),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: _done ? AppColors.success : AppColors.primary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: _handleTap,
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Icon(
                _done ? Icons.check_circle_rounded : Icons.check_rounded,
                key: ValueKey(_done),
              ),
            ),
            label: Text(context.tr('today.taken')),
          ),
        ),
      );
}

/// Loading placeholder card while today's schedule fetches.
class DoseSkeleton extends StatelessWidget {
  const DoseSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Shimmer.fromColors(
        baseColor: dark ? Colors.white12 : Colors.grey.shade300,
        highlightColor: dark ? Colors.white24 : Colors.grey.shade100,
        child: const GlassCard(
          margin: EdgeInsets.zero,
          radius: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(radius: 20),
                SizedBox(width: 12),
                Expanded(child: SizedBox(height: 18)),
                SizedBox(width: 50, height: 18),
              ]),
              SizedBox(height: 12),
              SizedBox(width: 180, height: 14),
              SizedBox(height: 12),
              SizedBox(width: double.infinity, height: 42),
            ],
          ),
        ),
      ),
    );
  }
}
