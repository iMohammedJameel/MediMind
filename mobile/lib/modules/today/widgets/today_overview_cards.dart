import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/dose_event_model.dart';
import '../../../shared/components/components.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/styles/colors.dart';
import '../../../shared/utils/formatters.dart';

bool _arabicDigitsOn() {
  try {
    return CacheHelper.getArabicDigits();
  } catch (_) {
    return true;
  }
}

/// Daily progress summary glass card.
class TodayProgressCard extends StatelessWidget {
  final AdherenceSummary summary;
  final List<DoseEventModel> doses;

  const TodayProgressCard({
    super.key,
    required this.summary,
    required this.doses,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final percent = summary.percentDueSoFar(doses);
    final arabicDigits = _arabicDigitsOn();
    final pctText = AppFormatters.digits('${(percent * 100).round()}',
        arabicIndic: arabicDigits);
    final takenText =
        AppFormatters.digits('${summary.taken}', arabicIndic: arabicDigits);
    final remainingText = AppFormatters.digits(
        '${summary.pending + summary.late}',
        arabicIndic: arabicDigits);

    return GlassCard(
      margin: EdgeInsets.zero,
      radius: 24,
      padding: const EdgeInsets.all(18),
      tint: dark
          ? const Color(0xFF17483B).withValues(alpha: .72)
          : const Color(0xFFDCEFE4).withValues(alpha: .74),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.tr('home.todayProgress'),
                  style: TextStyle(
                    color: dark ? Colors.white70 : AppColors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: dark
                      ? AppColors.tealDark.withValues(alpha: .18)
                      : Colors.white.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pctText%',
                  style: TextStyle(
                    color: dark ? const Color(0xFF5EEAD4) : AppColors.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            '$takenText ${context.tr('home.dosesTaken')}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : AppColors.brandText,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 1),
              minHeight: 8,
              backgroundColor: dark
                  ? Colors.white.withValues(alpha: .15)
                  : Colors.white.withValues(alpha: .8),
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MiniStat(
                icon: Icons.check_circle_outline,
                value: takenText,
                label: context.tr('today.takenDone'),
                color: const Color(0xFF2E8A64),
              ),
              const SizedBox(width: 10),
              _MiniStat(
                icon: Icons.schedule_rounded,
                value: remainingText,
                label: context.tr('home.remaining'),
                color: AppColors.amberAccent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
            Text(value,
                style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white70
                      : AppColors.secondaryText,
                ),
              ),
            ),
          ],
        ),
      );
}

/// Interactive next-dose highlight card (tapping opens quick alarm/confirm).
class NextDoseCard extends StatelessWidget {
  final DoseEventModel? next;
  final VoidCallback? onTap;

  const NextDoseCard({super.key, required this.next, this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      margin: EdgeInsets.zero,
      radius: 24,
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: dark
                      ? AppColors.tealDark.withValues(alpha: .18)
                      : const Color(0xFFDCEFE4).withValues(alpha: .9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.medication_rounded,
                    size: 29,
                    color: dark ? const Color(0xFF5EEAD4) : AppColors.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('today.nextDose'),
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.white60 : AppColors.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      next == null
                          ? context.tr('today.noNext')
                          : next!.medicationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: dark ? Colors.white : AppColors.brandText,
                      ),
                    ),
                    if (next != null)
                      Text(
                        next!.timeLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: dark
                              ? const Color(0xFF5EEAD4)
                              : AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              if (next != null)
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 15,
                    color: dark ? Colors.white60 : AppColors.secondaryText),
            ],
          ),
        ),
      ),
    );
  }
}

/// Scan OCR & Add Medication shortcuts row.
class TodayQuickActions extends StatelessWidget {
  final String scanLabel;
  final String addLabel;
  final VoidCallback onScan;
  final VoidCallback onAdd;

  const TodayQuickActions({
    super.key,
    required this.scanLabel,
    required this.addLabel,
    required this.onScan,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor =
        dark ? const Color(0xFF5EEAD4) : AppColors.primary;
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onScan,
            icon: const Icon(Icons.document_scanner_outlined),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(scanLabel, maxLines: 1),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: secondaryColor,
              backgroundColor: dark
                  ? const Color(0xFF172A24).withValues(alpha: .72)
                  : Colors.white.withValues(alpha: .4),
              minimumSize: const Size.fromHeight(50),
              side: BorderSide(
                color: dark
                    ? const Color(0xFF5EEAD4).withValues(alpha: .42)
                    : const Color(0xFF9EC9B0),
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(addLabel, maxLines: 1),
            ),
          ),
        ),
      ],
    );
  }
}
