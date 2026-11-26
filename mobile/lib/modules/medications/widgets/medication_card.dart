import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/medication_model.dart';
import '../../../shared/components/components.dart';
import '../../../shared/components/refill_sheet.dart';
import '../../../shared/styles/colors.dart';
import '../../../shared/utils/medication_icons.dart';

/// Displays one medication row with thumbnail/form icon, meal instructions,
/// active status, active refill badge, actions menu, and low-stock CTA.
class MedicationCard extends StatelessWidget {
  final MedicationModel med;
  final bool hasActiveRefill;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  const MedicationCard({
    super.key,
    required this.med,
    this.hasActiveRefill = false,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = med.resolvedImageUrl;
    final mealKey = MedicationIcons.mealLabelKey(med.relationToMeals);
    final subtitleParts = [
      '${med.dosesPerDay} ${context.tr('meds.perDay')}',
      med.isActive ? context.tr('common.active') : context.tr('common.inactive'),
      if (mealKey != null) context.tr(mealKey),
    ];
    return GlassCard(
      child: Column(
        children: [
          ListTile(
            leading: (imageUrl ?? '').isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      imageUrl!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        MedicationIcons.forForm(med.formType),
                        color: med.isActive
                            ? AppColors.teal
                            : AppColors.textSecondary,
                      ),
                    ),
                  )
                : Icon(
                    MedicationIcons.forForm(med.formType),
                    color:
                        med.isActive ? AppColors.teal : AppColors.textSecondary,
                  ),
            title: Text(med.name),
            subtitle: Text(subtitleParts.join(' • ')),
            trailing: PopupMenuButton<String>(
              onSelected: (action) {
                switch (action) {
                  case 'refill':
                    showRefillBottomSheet(context, med);
                  case 'edit':
                    onEdit();
                  case 'toggle':
                    onToggleActive();
                  case 'delete':
                    onDelete();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'refill',
                  child: Text(context.tr('refill.request')),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Text(context.tr('common.edit')),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Text(med.isActive
                      ? context.tr('meds.deactivate')
                      : context.tr('meds.activate')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    context.tr('common.delete'),
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
          if (hasActiveRefill)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined,
                      size: 16, color: AppColors.info),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      context.tr('meds.activeRefill'),
                      style: const TextStyle(
                        color: AppColors.info,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (med.isLowStock)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${context.tr('refill.lowStock')} (${med.inventoryQuantity ?? 0})',
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    FilledButton.tonal(
                      onPressed: () => showRefillBottomSheet(context, med),
                      child: Text(context.tr('refill.request')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
