import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../models/dose_event_model.dart';
import '../../shared/components/components.dart';
import '../../shared/components/refill_sheet.dart';
import '../../shared/styles/colors.dart';
import '../../shared/utils/formatters.dart';
import 'cubit/patient_detail_cubit.dart';
import 'cubit/patient_detail_states.dart';
import 'widgets/patient_detail_tiles.dart';

/// Caregiver view of one patient: today's doses + 7-day adherence + meds/stock
/// + confirm & refill on behalf.
class PatientDetailScreen extends StatelessWidget {
  final String patientId;
  final String? patientName;
  final String? patientPhone;
  final String? emergencyPhone;

  const PatientDetailScreen({
    super.key,
    required this.patientId,
    this.patientName,
    this.patientPhone,
    this.emergencyPhone,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PatientDetailCubit(patientId)..load(),
      child: _PatientDetailView(
        patientId: patientId,
        patientName: patientName,
        patientPhone: patientPhone,
        emergencyPhone: emergencyPhone,
      ),
    );
  }
}

class _PatientDetailView extends StatefulWidget {
  final String patientId;
  final String? patientName;
  final String? patientPhone;
  final String? emergencyPhone;

  const _PatientDetailView({
    required this.patientId,
    this.patientName,
    this.patientPhone,
    this.emergencyPhone,
  });

  @override
  State<_PatientDetailView> createState() => _PatientDetailViewState();
}

class _PatientDetailViewState extends State<_PatientDetailView> {
  int _tab = 0;

  Future<void> _callOrCopyPhone(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number.trim());
    var launched = false;
    try {
      launched = await launchUrl(uri);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      await Clipboard.setData(ClipboardData(text: number));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr('cg.callError')} ($number)',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PatientDetailCubit, PatientDetailStates>(
      listener: (context, state) {
        if (state is PatientDetailError &&
            context.read<PatientDetailCubit>().doses.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.trv(state.message))));
        }
      },
      builder: (context, state) {
        final cubit = context.read<PatientDetailCubit>();
        final dark = Theme.of(context).brightness == Brightness.dark;
        final accentColor = dark ? const Color(0xFF5EEAD4) : AppColors.primary;
        final doses = cubit.doses;
        final meds = cubit.medications;
        final taken = doses.where((d) => d.isTaken).length;
        final missed = doses.where((d) => d.isMissed).length;
        final weekPct = (cubit.weekAdherence * 100).round();
        final takenText =
            AppFormatters.digitsForLocale('$taken', locale: context.lang);
        final missedText =
            AppFormatters.digitsForLocale('$missed', locale: context.lang);
        final weekPctText =
            AppFormatters.digitsForLocale('$weekPct', locale: context.lang);

        return Scaffold(
          appBar: AppBar(
            title: Text((widget.patientName != null &&
                    widget.patientName!.isNotEmpty)
                ? widget.patientName!
                : context.tr('cg.detail')),
            actions: [
              IconButton(
                tooltip: context.tr('refill.myOrders'),
                icon: const Icon(Icons.receipt_long_outlined),
                onPressed: () =>
                    showRefillOrdersDialog(context, patientId: widget.patientId),
              ),
            ],
          ),
          body: state is PatientDetailLoading
              ? const Center(child: CircularProgressIndicator())
              : state is PatientDetailError && doses.isEmpty
                  ? ErrorWithRetry(
                      message: context.trv(state.message), onRetry: cubit.load)
                  : RefreshIndicator(
                      onRefresh: () => cubit.load(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _summary(
                                  context,
                                  context.tr('cg.takenToday'),
                                  takenText,
                                  AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _summary(
                                  context,
                                  context.tr('cg.missed'),
                                  missedText,
                                  AppColors.danger,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _summary(
                                  context,
                                  context.tr('cg.weekAdherence'),
                                  '$weekPctText%',
                                  accentColor,
                                ),
                              ),
                            ],
                          ),
                          if ((widget.patientPhone ?? '').isNotEmpty ||
                              (widget.emergencyPhone ?? '').isNotEmpty) ...[
                            const SizedBox(height: 10),
                            GlassCard(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 6,
                                children: [
                                  if ((widget.patientPhone ?? '').isNotEmpty)
                                    ActionChip(
                                      avatar: Icon(Icons.call_outlined,
                                          size: 16, color: accentColor),
                                      label: Text(
                                          '${context.tr('cg.callPatient')}: ${widget.patientPhone}'),
                                      onPressed: () => _callOrCopyPhone(
                                          context, widget.patientPhone!),
                                    ),
                                  if ((widget.emergencyPhone ?? '').isNotEmpty)
                                    ActionChip(
                                      avatar: const Icon(
                                          Icons.emergency_outlined,
                                          size: 16,
                                          color: AppColors.danger),
                                      label: Text(
                                          '${context.tr('cg.callEmergency')}: ${widget.emergencyPhone}'),
                                      onPressed: () => _callOrCopyPhone(
                                          context, widget.emergencyPhone!),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SegmentedButton<int>(
                            segments: [
                              ButtonSegment(
                                value: 0,
                                icon: const Icon(Icons.calendar_today_outlined,
                                    size: 18),
                                label: Text(context.tr('cg.tabDoses')),
                              ),
                              ButtonSegment(
                                value: 1,
                                icon: const Icon(Icons.medication_outlined,
                                    size: 18),
                                label: Text(
                                    '${context.tr('cg.tabMeds')} (${meds.length})'),
                              ),
                            ],
                            selected: {_tab},
                            onSelectionChanged: (s) =>
                                setState(() => _tab = s.first),
                          ),
                          const SizedBox(height: 12),
                          if (_tab == 0)
                            if (doses.isEmpty)
                              GlassCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    context.tr('home.noDoses'),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            else
                              ...doses.map((d) => PatientDoseTile(
                                    dose: d,
                                    busy: state is PatientDetailActionLoading &&
                                        state.doseEventId == d.id,
                                    onConfirm: () => _confirmDoseForPatient(
                                        context, cubit, d),
                                  ))
                          else if (meds.isEmpty)
                            GlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Text(
                                  context.tr('meds.emptyList'),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          else
                            ...meds.map((med) => PatientMedTile(
                                  med: med,
                                  patientId: widget.patientId,
                                )),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  void _confirmDoseForPatient(
      BuildContext context, PatientDetailCubit cubit, DoseEventModel d) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('cg.confirmDoseTitle')),
        content: SingleChildScrollView(
          child: Text(context
              .tr('cg.confirmDoseBody')
              .replaceAll('{med}', d.medicationName)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('common.cancel')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              cubit.confirmDose(d.id);
            },
            child: Text(context.tr('common.confirm')),
          ),
        ],
      ),
    );
  }

  Widget _summary(
          BuildContext context, String label, String value, Color color) =>
      GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        tint: color.withValues(alpha: 0.12),
        child: Column(
          children: [
            Text(value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}
