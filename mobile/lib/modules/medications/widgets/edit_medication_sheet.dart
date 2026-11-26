import 'package:flutter/material.dart';

import '../../../l10n/app_strings.dart';
import '../../../models/medication_model.dart';
import '../../../shared/components/components.dart';
import '../../../shared/utils/medication_icons.dart';
import '../cubit/medications_cubit.dart';

/// Opens the full bottom sheet to edit a medication's schedule, slot times,
/// inventory, meal relation, chronic status, and notes.
void showEditMedicationSheet(
  BuildContext context,
  MedicationsCubit cubit,
  MedicationModel med,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _EditMedicationSheet(cubit: cubit, med: med),
  );
}

class _EditMedicationSheet extends StatefulWidget {
  final MedicationsCubit cubit;
  final MedicationModel med;

  const _EditMedicationSheet({required this.cubit, required this.med});

  @override
  State<_EditMedicationSheet> createState() => _EditMedicationSheetState();
}

class _EditMedicationSheetState extends State<_EditMedicationSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _doses;
  late final TextEditingController _qty;
  late final TextEditingController _threshold;
  late final TextEditingController _notes;
  late TimeOfDay _time;
  late String _frequency;
  late String _meal;
  late bool _isChronic;
  late List<TimeOfDay> _slotTimes;

  @override
  void initState() {
    super.initState();
    final med = widget.med;
    _doses = TextEditingController(text: med.dosesPerDay.toString());
    _qty = TextEditingController(text: (med.inventoryQuantity ?? 30).toString());
    _threshold =
        TextEditingController(text: (med.refillThreshold ?? 5).toString());
    _notes = TextEditingController(text: med.notes);
    final (h, m) = med.firstDoseParts;
    _time = TimeOfDay(hour: h, minute: m);
    _frequency =
        const ['DAILY', 'WEEKLY', 'AS_NEEDED'].contains(med.frequency)
            ? med.frequency
            : 'DAILY';
    _meal = MedicationIcons.normalizeMeal(med.relationToMeals);
    _isChronic = med.isChronic;
    _slotTimes = med.timesOfDay.isNotEmpty
        ? med.timesOfDay.map((s) {
            final p = s.split(':');
            return TimeOfDay(
              hour: int.tryParse(p.isNotEmpty ? p[0] : '') ?? h,
              minute: int.tryParse(p.length > 1 ? p[1] : '') ?? m,
            );
          }).toList()
        : List.generate(med.dosesPerDay.clamp(1, 6), (i) {
            final step = med.dosesPerDay <= 1 ? 0 : (24 ~/ med.dosesPerDay);
            final mins = (h * 60 + m + i * step * 60) % (24 * 60);
            return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
          });
  }

  @override
  void dispose() {
    _doses.dispose();
    _qty.dispose();
    _threshold.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _syncSlots(int count) {
    final n = count.clamp(1, 6);
    final step = n == 1 ? 0 : (24 ~/ n);
    final firstMins = _time.hour * 60 + _time.minute;
    _slotTimes = List.generate(n, (i) {
      if (i == 0) return _time;
      if (i < _slotTimes.length) return _slotTimes[i];
      final mins = (firstMins + i * step * 60) % (24 * 60);
      return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.med.name,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _frequency,
                decoration: InputDecoration(
                  labelText: context.tr('meds.frequency'),
                  prefixIcon: const Icon(Icons.repeat_outlined),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'DAILY',
                      child: Text(context.tr('meds.freq.daily'))),
                  DropdownMenuItem(
                      value: 'WEEKLY',
                      child: Text(context.tr('meds.freq.weekly'))),
                  DropdownMenuItem(
                      value: 'AS_NEEDED',
                      child: Text(context.tr('meds.freq.asNeeded'))),
                ],
                onChanged: (v) =>
                    setState(() => _frequency = v ?? 'DAILY'),
              ),
              const SizedBox(height: 12),
              if (_frequency != 'AS_NEEDED') ...[
                DefaultFormField(
                  controller: _doses,
                  label: context.tr('meds.dosesPerDay'),
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final parsed = int.tryParse(v.trim());
                    if (parsed != null && parsed >= 1 && parsed <= 6) {
                      setState(() => _syncSlots(parsed));
                    }
                  },
                  validator: (v) => (int.tryParse(v ?? '0') ?? 0) < 1
                      ? context.tr('common.required')
                      : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _time);
                    if (t != null && mounted) {
                      setState(() {
                        _time = t;
                        _syncSlots(int.tryParse(_doses.text) ?? 1);
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                        labelText: context.tr('meds.firstDose')),
                    child: Text(_fmtTod(_time)),
                  ),
                ),
                if (_slotTimes.length > 1) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < _slotTimes.length; i++)
                        ActionChip(
                          avatar: const Icon(Icons.schedule, size: 16),
                          label: Text(
                              '${context.tr('meds.doseNum').replaceAll('{n}', '${i + 1}')}: ${_fmtTod(_slotTimes[i])}'),
                          onPressed: () async {
                            final t = await showTimePicker(
                                context: context, initialTime: _slotTimes[i]);
                            if (t != null && mounted) {
                              setState(() {
                                _slotTimes[i] = t;
                                if (i == 0) _time = t;
                              });
                            }
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: DefaultFormField(
                      controller: _qty,
                      label: context.tr('meds.inventory'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DefaultFormField(
                      controller: _threshold,
                      label: context.tr('meds.refillThreshold'),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _meal,
                decoration: InputDecoration(
                  labelText: context.tr('meds.relationToMeals'),
                  prefixIcon: const Icon(Icons.restaurant_outlined),
                ),
                items: [
                  DropdownMenuItem(
                      value: 'NONE', child: Text(context.tr('meds.meal.none'))),
                  DropdownMenuItem(
                      value: 'BEFORE_MEALS',
                      child: Text(context.tr('meds.meal.before'))),
                  DropdownMenuItem(
                      value: 'AFTER_MEALS',
                      child: Text(context.tr('meds.meal.after'))),
                  DropdownMenuItem(
                      value: 'WITH_FOOD',
                      child: Text(context.tr('meds.meal.with'))),
                  DropdownMenuItem(
                      value: 'ON_EMPTY_STOMACH',
                      child: Text(context.tr('meds.meal.empty'))),
                ],
                onChanged: (v) => setState(() => _meal = v ?? 'NONE'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.tr('meds.chronic')),
                value: _isChronic,
                onChanged: (v) => setState(() => _isChronic = v),
              ),
              DefaultFormField(
                controller: _notes,
                label: context.tr('meds.notes'),
                prefixIcon: Icons.notes_outlined,
              ),
              const SizedBox(height: 16),
              DefaultButton(
                label: context.tr('common.save'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.cubit.updateMedication(
                      widget.med.id,
                      frequency: _frequency,
                      dosesPerDay: int.tryParse(_doses.text) ?? 1,
                      firstDoseTime: _fmtTod(_time),
                      timesOfDay: _frequency == 'AS_NEEDED'
                          ? null
                          : _slotTimes.map(_fmtTod).toList(),
                      inventoryQuantity: int.tryParse(_qty.text) ?? 30,
                      refillThreshold: int.tryParse(_threshold.text) ?? 5,
                      relationToMeals: _meal,
                      notes: _notes.text,
                      isChronic: _isChronic,
                    );
                    Navigator.of(context).pop();
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
