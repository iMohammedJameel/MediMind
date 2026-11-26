import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/dose_event_model.dart';
import '../../../models/medication_model.dart';
import '../../../shared/components/components.dart';
import '../../../shared/components/refill_sheet.dart';
import '../../../shared/styles/colors.dart';
import '../../../shared/utils/medication_icons.dart';

/// Dose row rendered in the caregiver's Patient Detail view.
class PatientDoseTile extends StatelessWidget {
  final DoseEventModel dose;
  final bool busy;
  final VoidCallback onConfirm;

  const PatientDoseTile({
    super.key,
    required this.dose,
    required this.busy,
    required this.onConfirm,
  });

  String _statusLabel(BuildContext context) => switch (dose.status) {
        'TAKEN' => context.tr('cg.taken'),
        'MISSED' => context.tr('cg.missed'),
        'LATE' => context.tr('cg.late'),
        'SKIPPED' => context.tr('cg.skipped'),
        _ => context.tr('cg.waiting'),
      };

  @override
  Widget build(BuildContext context) {
    final canConfirm = dose.isPending || dose.isLate;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                switch (dose.status) {
                  'TAKEN' => Icons.check_circle,
                  'MISSED' => Icons.cancel,
                  'LATE' => Icons.schedule,
                  'SKIPPED' => Icons.skip_next,
                  _ => Icons.hourglass_top,
                },
                color: switch (dose.status) {
                  'TAKEN' => AppColors.success,
                  'MISSED' => AppColors.danger,
                  'LATE' => AppColors.warning,
                  _ => AppColors.info,
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dose.medicationName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${dose.timeLabel} — ${_statusLabel(context)}',
                      style: TextStyle(
                          fontSize: 12, color: Theme.of(context).hintColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (canConfirm) ...[
            const SizedBox(height: 10),
            busy
                ? const Center(
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : SizedBox(
                    height: 44,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(64, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        textStyle: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                      onPressed: onConfirm,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(context.tr('cg.taken')),
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}

/// Medication + stock row rendered in the caregiver's Patient Detail view.
class PatientMedTile extends StatelessWidget {
  final MedicationModel med;
  final String patientId;

  const PatientMedTile({
    super.key,
    required this.med,
    required this.patientId,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                MedicationIcons.forForm(med.formType),
                color: med.isActive ? AppColors.teal : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      '${med.dosesPerDay} ${context.tr('meds.perDay')} • '
                      '${context.tr('meds.inventory')}: ${med.inventoryQuantity ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (med.isLowStock)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 16, color: AppColors.warning),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          context.tr('refill.lowStock'),
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                FilledButton.tonal(
                  onPressed: () =>
                      showRefillBottomSheet(context, med, patientId: patientId),
                  child: Text(context.tr('refill.request')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
