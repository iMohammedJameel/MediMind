import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../app_router.dart';
import '../../l10n/app_strings.dart';
import '../../models/medication_model.dart';
import '../../shared/components/components.dart';
import '../../shared/styles/colors.dart';
import 'cubit/scan_cubit.dart';
import 'cubit/scan_states.dart';

/// Camera screen: capture a prescription photo → multi-med OCR → review & batch save.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScanCubit(),
      child: const _ScanView(),
    );
  }
}

class _ScanView extends StatefulWidget {
  const _ScanView();

  @override
  State<_ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<_ScanView> {
  List<ScannedMedicationItem> _items = [];
  List<bool> _selected = [];

  void _syncItems(ScanResultModel result) {
    _items = List<ScannedMedicationItem>.from(result.medications);
    _selected = List<bool>.filled(_items.length, true);
  }

  Future<void> _showWarnings(List<InteractionWarningModel> warnings) async {
    if (!mounted || warnings.isEmpty) return;
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

  Future<void> _editItemDialog(int index) async {
    final updated = await showDialog<ScannedMedicationItem>(
      context: context,
      builder: (_) => _EditScanItemDialog(item: _items[index]),
    );
    if (updated != null && mounted) {
      setState(() => _items[index] = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScanCubit, ScanStates>(
      listener: (context, state) async {
        if (state is ScanSuccess) {
          setState(() => _syncItems(state.result));
        } else if (state is ScanLowConfidence) {
          setState(() => _syncItems(state.result));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context
                .tr('scan.lowConfidence')
                .replaceAll('{pct}',
                    (state.result.confidence * 100).toStringAsFixed(0))),
            backgroundColor: AppColors.warning,
          ));
        } else if (state is ScanBatchSaved) {
          await _showWarnings(state.warnings);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(context
                  .tr('scan.batchSaved')
                  .replaceAll('{count}', '${state.count}')),
              backgroundColor: AppColors.success,
            ));
            context.go(Routes.medications);
          }
        }
      },
      builder: (context, state) {
        final cubit = context.read<ScanCubit>();
        final image = cubit.imageBytes;
        final result = state is ScanSuccess
            ? state.result
            : state is ScanLowConfidence
                ? state.result
                : state is ScanBatchSaving
                    ? state.result
                    : null;
        final savingBatch = state is ScanBatchSaving;
        final selectedItems = [
          for (var i = 0; i < _items.length; i++)
            if (i < _selected.length && _selected[i]) _items[i],
        ];

        return Scaffold(
          appBar: AppBar(title: Text(context.tr('scan.title'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 200),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: image == null
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.document_scanner_outlined,
                                size: 46, color: AppColors.primary),
                            const SizedBox(height: 10),
                            Text(
                              context.tr('scan.hint'),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: [
                                _ScanTip(Icons.wb_sunny_outlined,
                                    context.tr('scan.tipLighting')),
                                _ScanTip(Icons.center_focus_strong_outlined,
                                    context.tr('scan.tipFocus')),
                                _ScanTip(Icons.pan_tool_alt_outlined,
                                    context.tr('scan.tipSteady')),
                              ],
                            ),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            height: 210,
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(16)),
                              child: InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 3.0,
                                child: Image.memory(image, fit: BoxFit.contain),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(
                              context.tr('scan.zoomHint'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: state is ScanProcessing || savingBatch
                          ? null
                          : () => cubit.pickAndScan(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: Text(context.tr('scan.camera')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: state is ScanProcessing || savingBatch
                          ? null
                          : () => cubit.pickAndScan(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(context.tr('scan.gallery')),
                    ),
                  ),
                ],
              ),
              if (state is ScanProcessing) ...[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(context.tr('scan.processing'),
                    textAlign: TextAlign.center),
              ],
              if (state is ScanError) ...[
                const SizedBox(height: 16),
                Text(context.trv(state.message),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger)),
              ],
              if (result != null && _items.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(context.tr('scan.resultTitle'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 8),
                for (var i = 0; i < _items.length; i++)
                  GlassCard(
                    child: CheckboxListTile(
                      value: i < _selected.length ? _selected[i] : true,
                      onChanged: savingBatch
                          ? null
                          : (v) => setState(() => _selected[i] = v ?? true),
                      title: Text(_items[i].name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: Text(
                          '${_items[i].dosesPerDay} ${context.tr('meds.perDay')} • ${context.tr('scan.confidence')}: ${(_items[i].confidence * 100).toStringAsFixed(0)}%'),
                      secondary: IconButton(
                        tooltip: context.tr('common.edit'),
                        icon: const Icon(Icons.edit_outlined),
                        onPressed:
                            savingBatch ? null : () => _editItemDialog(i),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                DefaultButton(
                  label: context
                      .tr('scan.saveAll')
                      .replaceAll('{count}', '${selectedItems.length}'),
                  loading: savingBatch,
                  onPressed: selectedItems.isEmpty
                      ? null
                      : () => cubit.saveScannedMedications(selectedItems),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: savingBatch
                      ? null
                      : () => context.go(
                          '${Routes.medications}?scan=${Uri.encodeComponent((selectedItems.isNotEmpty ? selectedItems.first.name : result.name) ?? '')}'),
                  icon: const Icon(Icons.tune_outlined),
                  label: Text(context.tr('scan.continue')),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ScanTip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _ScanTip(this.icon, this.text);

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(icon, size: 15, color: AppColors.primary),
        label: Text(text, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
      );
}

class _EditScanItemDialog extends StatefulWidget {
  final ScannedMedicationItem item;
  const _EditScanItemDialog({required this.item});

  @override
  State<_EditScanItemDialog> createState() => _EditScanItemDialogState();
}

class _EditScanItemDialogState extends State<_EditScanItemDialog> {
  late final TextEditingController _nameCtrl;
  late int _doses;
  late String _freq;
  late String _formType;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.item.name);
    _doses = widget.item.dosesPerDay;
    _freq = widget.item.frequency;
    _formType = widget.item.formType;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('meds.editTitle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: context.tr('meds.name')),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _formType,
              isExpanded: true,
              decoration:
                  InputDecoration(labelText: context.tr('meds.formType')),
              items: [
                DropdownMenuItem(
                    value: 'TABLET',
                    child: Text(context.tr('meds.form.tablet'))),
                DropdownMenuItem(
                    value: 'CAPSULE',
                    child: Text(context.tr('meds.form.capsule'))),
                DropdownMenuItem(
                    value: 'SYRUP',
                    child: Text(context.tr('meds.form.syrup'))),
                DropdownMenuItem(
                    value: 'INJECTION',
                    child: Text(context.tr('meds.form.injection'))),
                DropdownMenuItem(
                    value: 'DROP', child: Text(context.tr('meds.form.drop'))),
                DropdownMenuItem(
                    value: 'CREAM',
                    child: Text(context.tr('meds.form.cream'))),
                DropdownMenuItem(
                    value: 'OTHER',
                    child: Text(context.tr('meds.form.other'))),
              ],
              onChanged: (v) => setState(() => _formType = v ?? 'TABLET'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _freq,
              isExpanded: true,
              decoration:
                  InputDecoration(labelText: context.tr('meds.frequency')),
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
              onChanged: (v) => setState(() => _freq = v ?? 'DAILY'),
            ),
            const SizedBox(height: 12),
            if (_freq != 'AS_NEEDED')
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(context.tr('meds.dosesPerDay'))),
                  Row(
                    children: [
                      IconButton(
                        tooltip: '-',
                        onPressed:
                            _doses > 1 ? () => setState(() => _doses--) : null,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text('$_doses',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      IconButton(
                        tooltip: '+',
                        onPressed:
                            _doses < 6 ? () => setState(() => _doses++) : null,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.tr('common.cancel')),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            Navigator.pop(
              context,
              name.isEmpty
                  ? null
                  : widget.item.copyWith(
                      name: name,
                      formType: _formType,
                      dosesPerDay: _doses,
                      frequency: _freq,
                    ),
            );
          },
          child: Text(context.tr('common.save')),
        ),
      ],
    );
  }
}
