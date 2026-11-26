import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/app_strings.dart';
import '../../../services/refill_service.dart';
import '../../../shared/components/components.dart';
import '../../../shared/styles/colors.dart';
import '../cubit/medications_cubit.dart';
import '../cubit/medications_states.dart';

/// Expandable form to add a new medication with custom slot times & photo.
class AddMedicationForm extends StatefulWidget {
  final String? initialName;

  const AddMedicationForm({super.key, this.initialName});

  @override
  State<AddMedicationForm> createState() => _AddMedicationFormState();
}

class _AddMedicationFormState extends State<AddMedicationForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _dosesPerDay = TextEditingController(text: '1');
  final _initialQuantity = TextEditingController(text: '30');
  final _doseAmount = TextEditingController(text: '1');
  final _refillThreshold = TextEditingController(text: '5');
  final _durationDays = TextEditingController(text: '7');
  final _notes = TextEditingController();

  String _formType = 'TABLET';
  String _frequency = 'DAILY';
  String _relationToMeals = 'NONE';
  TimeOfDay _time = const TimeOfDay(hour: 8, minute: 0);
  List<TimeOfDay> _slotTimes = [const TimeOfDay(hour: 8, minute: 0)];
  DateTime? _expirationDate;
  bool _isChronic = false;
  bool _showAdvanced = false;
  int _step = 0;

  Uint8List? _imageBytes;
  String? _imageUploadUrl;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null && widget.initialName!.isNotEmpty) {
      _name.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dosesPerDay.dispose();
    _initialQuantity.dispose();
    _doseAmount.dispose();
    _refillThreshold.dispose();
    _durationDays.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _resetAfterSave() {
    _name.clear();
    _notes.clear();
    setState(() {
      _imageBytes = null;
      _imageUploadUrl = null;
      _expirationDate = null;
      _time = const TimeOfDay(hour: 8, minute: 0);
      _dosesPerDay.text = '1';
      _slotTimes = [const TimeOfDay(hour: 8, minute: 0)];
      _step = 0;
    });
  }

  void _syncSlotTimes(int count) {
    final n = count.clamp(1, 6);
    final step = n == 1 ? 0 : (24 ~/ n);
    final firstMins = _time.hour * 60 + _time.minute;
    _slotTimes = List.generate(n, (i) {
      if (i == 0) return _time;
      if (i < _slotTimes.length && _slotTimes.length == n) return _slotTimes[i];
      final mins = (firstMins + i * step * 60) % (24 * 60);
      return TimeOfDay(hour: mins ~/ 60, minute: mins % 60);
    });
  }

  static String _fmtTod(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null) {
      setState(() {
        _time = t;
        _syncSlotTimes(int.tryParse(_dosesPerDay.text) ?? 1);
      });
    }
  }

  Future<void> _pickSlotTime(int index) async {
    final t =
        await showTimePicker(context: context, initialTime: _slotTimes[index]);
    if (t != null) {
      setState(() {
        _slotTimes[index] = t;
        if (index == 0) _time = t;
      });
    }
  }

  Future<void> _pickExpirationDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _expirationDate = picked);
  }

  Future<void> _pickMedicationImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 82,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _uploadingImage = true;
      });
      final url = await RefillService()
          .uploadMedicationImage(bytes, filename: picked.name);
      if (!mounted) return;
      setState(() {
        _imageUploadUrl = url.isEmpty ? null : url;
        _uploadingImage = false;
      });
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('meds.imageUploadFail')),
          backgroundColor: AppColors.warning,
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _uploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('meds.imageUploadFail'))));
      }
    }
  }

  Future<void> _chooseImageSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(context.tr('scan.camera')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(context.tr('scan.gallery')),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) _pickMedicationImage(source);
  }

  @override
  Widget build(BuildContext context) {
    final expLabel = _expirationDate != null
        ? '${_expirationDate!.year}-${_expirationDate!.month.toString().padLeft(2, '0')}-${_expirationDate!.day.toString().padLeft(2, '0')}'
        : context.tr('meds.expirationDate');

    return BlocListener<MedicationsCubit, MedicationsStates>(
      listener: (context, state) {
        if (state is MedicationSaved) _resetAfterSave();
      },
      child: BlocBuilder<MedicationsCubit, MedicationsStates>(
        builder: (context, state) {
          final cubit = context.read<MedicationsCubit>();
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: (widget.initialName?.isNotEmpty ?? false),
              tilePadding: const EdgeInsets.symmetric(horizontal: 4),
              title: Text(
                context.tr('meds.addNew'),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Guided 2-step progress pills (reduces cognitive load).
                      Row(
                        children: [
                          Expanded(
                            child: _StepPill(
                              label: context.tr('meds.step1'),
                              active: _step == 0,
                              onTap: () => setState(() => _step = 0),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StepPill(
                              label: context.tr('meds.step2'),
                              active: _step == 1,
                              onTap: () {
                                if (_formKey.currentState!.validate()) {
                                  setState(() => _step = 1);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_step == 0) ...[
                        DefaultFormField(
                          controller: _name,
                          label: context.tr('meds.name'),
                          prefixIcon: Icons.medication_outlined,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? context.tr('common.required')
                              : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _formType,
                          decoration: InputDecoration(
                            labelText: context.tr('meds.formType'),
                            prefixIcon: const Icon(Icons.category_outlined),
                          ),
                          items: [
                            DropdownMenuItem(value: 'TABLET', child: Text(context.tr('meds.form.tablet'), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'CAPSULE', child: Text(context.tr('meds.form.capsule'), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'SYRUP', child: Text(context.tr('meds.form.syrup'), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'INJECTION', child: Text(context.tr('meds.form.injection'), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'DROP', child: Text(context.tr('meds.form.drop'), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'CREAM', child: Text(context.tr('meds.form.cream'), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'OTHER', child: Text(context.tr('meds.form.other'), overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) =>
                              setState(() => _formType = v ?? 'TABLET'),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _uploadingImage ? null : _chooseImageSource,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: context.tr('meds.image'),
                              prefixIcon: const Icon(Icons.add_a_photo_outlined),
                            ),
                            child: _uploadingImage
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (_imageBytes != null) ...[
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: Image.memory(
                                            _imageBytes!,
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            _imageUploadUrl != null
                                                ? context.tr('meds.imageReady')
                                                : context
                                                    .tr('meds.imageUploading'),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ] else
                                        Expanded(
                                            child: Text(
                                                context.tr('meds.imageHint'))),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                            backgroundColor: AppColors.primary,
                          ),
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              setState(() => _step = 1);
                            }
                          },
                          icon: const Icon(Icons.arrow_forward_rounded),
                          label: Text(context.tr('meds.nextStep')),
                        ),
                      ] else ...[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: _frequency,
                          decoration: InputDecoration(
                            labelText: context.tr('meds.frequency'),
                            prefixIcon: const Icon(Icons.repeat_outlined),
                          ),
                          items: [
                            DropdownMenuItem(value: 'DAILY', child: Text(context.tr('meds.freq.daily'), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'WEEKLY', child: Text(context.tr('meds.freq.weekly'), overflow: TextOverflow.ellipsis)),
                            DropdownMenuItem(value: 'AS_NEEDED', child: Text(context.tr('meds.freq.asNeeded'), overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) =>
                              setState(() => _frequency = v ?? 'DAILY'),
                        ),
                        const SizedBox(height: 12),
                        if (_frequency != 'AS_NEEDED') ...[
                          DefaultFormField(
                            controller: _dosesPerDay,
                            label: context.tr('meds.dosesPerDay'),
                            prefixIcon: Icons.repeat_one_outlined,
                            keyboardType: TextInputType.number,
                            onChanged: (v) {
                              final parsed = int.tryParse(v.trim());
                              if (parsed != null && parsed >= 1 && parsed <= 6) {
                                setState(() => _syncSlotTimes(parsed));
                              }
                            },
                            validator: (v) =>
                                (int.tryParse(v ?? '') == null ||
                                        int.parse(v!) < 1)
                                    ? context.tr('common.required')
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          InkWell(
                            onTap: _pickTime,
                            borderRadius: BorderRadius.circular(14),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: context.tr('meds.firstDose'),
                                prefixIcon: const Icon(Icons.access_time),
                              ),
                              child: Text(
                                _fmtTod(_time),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16),
                              ),
                            ),
                          ),
                          if (_slotTimes.length > 1) ...[
                            const SizedBox(height: 10),
                            Text(context.tr('meds.customTimes'),
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                for (var i = 0; i < _slotTimes.length; i++)
                                  ActionChip(
                                    avatar:
                                        const Icon(Icons.schedule, size: 16),
                                    label: Text(
                                        '${context.tr('meds.doseNum').replaceAll('{n}', '${i + 1}')}: ${_fmtTod(_slotTimes[i])}'),
                                    onPressed: () => _pickSlotTime(i),
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
                                controller: _initialQuantity,
                                label: context.tr('meds.initialQuantity'),
                                prefixIcon: Icons.inventory_2_outlined,
                                keyboardType: TextInputType.number,
                                validator: (v) =>
                                    (int.tryParse(v ?? '') == null ||
                                            int.parse(v!) < 1)
                                        ? context.tr('common.required')
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DefaultFormField(
                                controller: _doseAmount,
                                label: context.tr('meds.doseAmount'),
                                prefixIcon: Icons.colorize_outlined,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                validator: (v) =>
                                    (double.tryParse(v ?? '') == null ||
                                            double.parse(v!) <= 0)
                                        ? context.tr('common.required')
                                        : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            children: [
                              SwitchListTile(
                                title: Text(context.tr('meds.chronic'),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                                value: _isChronic,
                                onChanged: (v) =>
                                    setState(() => _isChronic = v),
                              ),
                              if (!_isChronic)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      left: 16, right: 16, bottom: 12),
                                  child: DefaultFormField(
                                    controller: _durationDays,
                                    label: context.tr('meds.durationDays'),
                                    prefixIcon: Icons.calendar_month_outlined,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding:
                                const EdgeInsets.symmetric(horizontal: 4),
                            childrenPadding: const EdgeInsets.symmetric(
                                horizontal: 2, vertical: 8),
                            title: Text(
                              context.tr('meds.moreDetails'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            initiallyExpanded: _showAdvanced,
                            onExpansionChanged: (v) =>
                                setState(() => _showAdvanced = v),
                            children: [
                              const SizedBox(height: 6),
                              DefaultFormField(
                                controller: _refillThreshold,
                                label: context.tr('meds.refillThreshold'),
                                prefixIcon:
                                    Icons.notification_important_outlined,
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue: _relationToMeals,
                                decoration: InputDecoration(
                                  labelText:
                                      context.tr('meds.relationToMeals'),
                                  prefixIcon:
                                      const Icon(Icons.restaurant_outlined),
                                ),
                                items: [
                                  DropdownMenuItem(value: 'NONE', child: Text(context.tr('meds.meal.none'), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'BEFORE_MEALS', child: Text(context.tr('meds.meal.before'), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'AFTER_MEALS', child: Text(context.tr('meds.meal.after'), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'WITH_FOOD', child: Text(context.tr('meds.meal.with'), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'ON_EMPTY_STOMACH', child: Text(context.tr('meds.meal.empty'), overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (v) => setState(
                                    () => _relationToMeals = v ?? 'NONE'),
                              ),
                              const SizedBox(height: 12),
                              InkWell(
                                onTap: _pickExpirationDate,
                                borderRadius: BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText:
                                        context.tr('meds.expirationDate'),
                                    prefixIcon:
                                        const Icon(Icons.event_outlined),
                                  ),
                                  child: Text(expLabel,
                                      overflow: TextOverflow.ellipsis),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DefaultFormField(
                                controller: _notes,
                                label: context.tr('meds.notes'),
                                prefixIcon: Icons.notes_outlined,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => setState(() => _step = 0),
                              child: Text(context.tr('meds.prevStep')),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DefaultButton(
                                label: context.tr('meds.save'),
                                loading: state is MedicationSaving,
                                onPressed: () {
                                  if (_name.text.trim().isEmpty) {
                                    setState(() => _step = 0);
                                    return;
                                  }
                                  if (_formKey.currentState!.validate()) {
                                    cubit.createMedication(
                                      name: _name.text,
                                      formType: _formType,
                                      frequency: _frequency,
                                      dosesPerDay:
                                          int.tryParse(_dosesPerDay.text) ?? 1,
                                      firstDoseTime: _fmtTod(_time),
                                      timesOfDay: _frequency == 'AS_NEEDED'
                                          ? null
                                          : _slotTimes.map(_fmtTod).toList(),
                                      isChronic: _isChronic,
                                      durationDays:
                                          int.tryParse(_durationDays.text),
                                      initialQuantity:
                                          int.tryParse(_initialQuantity.text) ??
                                              30,
                                      doseAmount:
                                          double.tryParse(_doseAmount.text) ??
                                              1.0,
                                      refillThreshold:
                                          int.tryParse(_refillThreshold.text) ??
                                              5,
                                      relationToMeals: _relationToMeals,
                                      notes: _notes.text,
                                      expirationDate: _expirationDate,
                                      imageUrl: _imageUploadUrl,
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StepPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _StepPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: active ? scheme.secondaryContainer : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active ? scheme.primary : scheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? scheme.onSecondaryContainer : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
