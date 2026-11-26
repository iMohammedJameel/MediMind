import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../app_router.dart';
import '../../l10n/app_strings.dart';
import '../../models/medication_model.dart';
import '../../services/local_notifications_service.dart';
import '../../shared/components/components.dart';
import '../../shared/components/refill_sheet.dart';
import '../../shared/network/local/cache_helper.dart';
import '../../shared/styles/colors.dart';
import 'cubit/medications_cubit.dart';
import 'cubit/medications_states.dart';
import 'widgets/add_medication_form.dart';
import 'widgets/edit_medication_sheet.dart';
import 'widgets/medication_card.dart';

/// Medications tab: list + manual add form (pre-filled after OCR review),
/// plus edit / deactivate / delete / refill per medication.
class MedicationsScreen extends StatelessWidget {
  final String? scanResult;
  const MedicationsScreen({super.key, this.scanResult});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MedicationsCubit()..loadMedications(),
      child: _MedicationsView(scanResult: scanResult),
    );
  }
}

class _MedicationsView extends StatefulWidget {
  final String? scanResult;
  const _MedicationsView({this.scanResult});

  @override
  State<_MedicationsView> createState() => _MedicationsViewState();
}

enum _MedFilter { all, active, lowStock, chronic }

class _MedicationsViewState extends State<_MedicationsView> {
  final _search = TextEditingController();
  String _query = '';
  _MedFilter _filter = _MedFilter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _showWarnings(
      BuildContext context, List<InteractionWarningModel> warnings) async {
    if (!context.mounted || warnings.isEmpty) return;
    final locale = context.lang;
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('meds.interactionTitle')),
        content: Text(warnings
            .map((w) =>
                '${w.isHigh ? context.tr('meds.interactionHigh') : context.tr('meds.interactionWarn')}: ${w.effectFor(locale)}\n${w.recommendationFor(locale)}')
            .join('\n\n')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.tr('meds.understood')),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, MedicationsCubit cubit, MedicationModel med) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('meds.deleteConfirmTitle')),
        content: Text(context
            .tr('meds.deleteConfirmBody')
            .replaceAll('{name}', med.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.deleteMedication(med.id);
            },
            child: Text(context.tr('common.delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MedicationsCubit, MedicationsStates>(
      listener: (context, state) async {
        if (state is MedicationSaved) {
          await _showWarnings(context, state.warnings);
          if (!context.mounted) return;
          final needsExact = CacheHelper.getNotificationsEnabled() &&
              await LocalNotificationsService
                  .shouldPromptForExactAlarmPermission();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: Duration(seconds: needsExact ? 6 : 3),
              content: Text(context.tr(
                  needsExact ? 'alarm.exactPermHintMed' : 'meds.saved')),
              action: needsExact
                  ? SnackBarAction(
                      label: context.tr('alarm.exactPermAction'),
                      onPressed:
                          LocalNotificationsService.openExactAlarmSettings,
                    )
                  : null,
            ),
          );
        } else if (state is MedicationUpdated) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(context.tr('meds.updated'))));
        } else if (state is MedicationDeleted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(context.tr('meds.deleted'))));
        } else if (state is MedicationSaveError) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(context.trv(state.message))));
        }
      },
      builder: (context, state) {
        final cubit = context.read<MedicationsCubit>();

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('meds.title')),
            actions: [
              IconButton(
                tooltip: context.tr('today.scan'),
                icon: const Icon(Icons.document_scanner_outlined),
                onPressed: () => context.push(Routes.scan),
              ),
              IconButton(
                tooltip: context.tr('refill.myOrders'),
                icon: const Icon(Icons.receipt_long_outlined),
                onPressed: () => showRefillOrdersDialog(context),
              ),
            ],
          ),
          bottomNavigationBar: const PatientBottomNav(currentIndex: 1),
          body: state is MedicationsLoading
              ? const Center(child: CircularProgressIndicator())
              : state is MedicationsError
                  ? ErrorWithRetry(
                      message: context.trv(state.message),
                      onRetry: () => cubit.loadMedications(),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      children: [
                        if (state is MedicationsLoaded && state.fromCache)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Card(
                              color: AppColors.warning.withValues(alpha: 0.15),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.wifi_off, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(context.tr('today.offline')),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (cubit.medications.isNotEmpty) ...[
                          TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: context.tr('meds.searchHint'),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _query.isNotEmpty
                                  ? IconButton(
                                      tooltip: context.tr('common.cancel'),
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _search.clear();
                                        setState(() => _query = '');
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (v) =>
                                setState(() => _query = v.trim().toLowerCase()),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final (f, labelKey) in [
                                  (_MedFilter.all, 'meds.filterAll'),
                                  (_MedFilter.active, 'meds.filterActive'),
                                  (_MedFilter.lowStock, 'meds.filterLowStock'),
                                  (_MedFilter.chronic, 'meds.filterChronic'),
                                ])
                                  Padding(
                                    padding:
                                        const EdgeInsetsDirectional.only(end: 8),
                                    child: ChoiceChip(
                                      label: Text(context.tr(labelKey)),
                                      selected: _filter == f,
                                      onSelected: (_) =>
                                          setState(() => _filter = f),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(context.tr('meds.myMeds'),
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final filtered = cubit.medications.where((m) {
                              if (_query.isNotEmpty &&
                                  !m.name.toLowerCase().contains(_query)) {
                                return false;
                              }
                              return switch (_filter) {
                                _MedFilter.all => true,
                                _MedFilter.active => m.isActive,
                                _MedFilter.lowStock => m.isLowStock,
                                _MedFilter.chronic => m.isChronic,
                              };
                            }).toList();
                            if (filtered.isEmpty) {
                              return GlassCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      const Icon(Icons.medication_outlined,
                                          size: 40, color: AppColors.teal),
                                      const SizedBox(height: 10),
                                      Text(
                                        context.tr('meds.emptyList'),
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      if (cubit.medications.isEmpty) ...[
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                          onPressed: () =>
                                              context.push(Routes.scan),
                                          icon: const Icon(
                                              Icons.document_scanner_outlined),
                                          label: Text(context.tr('today.scan')),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: filtered
                                  .map((med) => MedicationCard(
                                        med: med,
                                        hasActiveRefill: cubit
                                            .activeRefillMedIds
                                            .contains(med.id),
                                        onEdit: () => showEditMedicationSheet(
                                            context, cubit, med),
                                        onToggleActive: () =>
                                            cubit.updateMedication(med.id,
                                                isActive: !med.isActive),
                                        onDelete: () =>
                                            _confirmDelete(context, cubit, med),
                                      ))
                                  .toList(),
                            );
                          },
                        ),
                        const Divider(height: 32),
                        AddMedicationForm(initialName: widget.scanResult),
                      ],
                    ),
        );
      },
    );
  }
}
