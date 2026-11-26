import 'dart:convert';

import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../models/medication_model.dart';
import '../../models/refill_model.dart';
import '../../services/analytics_service.dart';
import '../../services/refill_service.dart';
import '../network/local/cache_helper.dart';
import '../styles/colors.dart';
import 'components.dart';

/// Shared bottom sheet to request a medication refill (used by both the
/// patient Medications tab and the caregiver Patient Detail dashboard).
void showRefillBottomSheet(
  BuildContext context,
  MedicationModel med, {
  String? patientId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RefillSheet(
      med: med,
      patientId: patientId,
      messenger: ScaffoldMessenger.of(context),
    ),
  );
}

class _RefillSheet extends StatefulWidget {
  final MedicationModel med;
  final String? patientId;
  final ScaffoldMessengerState messenger;

  const _RefillSheet({
    required this.med,
    this.patientId,
    required this.messenger,
  });

  @override
  State<_RefillSheet> createState() => _RefillSheetState();
}

class _RefillSheetState extends State<_RefillSheet> {
  final _refillService = RefillService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantity;
  final _searchController = TextEditingController();
  final _street = TextEditingController();
  final _city = TextEditingController();
  final _zip = TextEditingController();

  String _fulfillment = 'PICKUP';
  bool _only24h = false;
  bool _onlyDelivery = false;
  String _query = '';
  bool _loading = true;
  bool _sending = false;
  List<PharmacyModel> _pharmacies = [];
  String? _pharmacyId;

  @override
  void initState() {
    super.initState();
    final suggestedQty =
        ((widget.med.doseAmount ?? 1) * 30).round().clamp(1, 360);
    _quantity = TextEditingController(text: '$suggestedQty');
    try {
      final raw = CacheHelper.getSavedDeliveryAddress();
      if (raw != null && raw.isNotEmpty) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _street.text = (map['street'] ?? '').toString();
        _city.text = (map['city'] ?? '').toString();
        _zip.text = (map['zipCode'] ?? '').toString();
      }
    } catch (_) {}

    _refillService.listPharmacies().then((list) {
      if (!mounted) return;
      setState(() {
        _pharmacies = list;
        _loading = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _quantity.dispose();
    _searchController.dispose();
    _street.dispose();
    _city.dispose();
    _zip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _pharmacies.where((p) {
      if (_only24h && !p.is24Hours) return false;
      if (_onlyDelivery && !p.offersDelivery) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final haystack = '${p.pharmacyName} ${p.locationLabel}'.toLowerCase();
        if (!haystack.contains(q)) return false;
      }
      return true;
    }).toList();

    if (_pharmacyId != null && !filtered.any((p) => p.id == _pharmacyId)) {
      _pharmacyId = null;
    }

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
              Text(context.tr('refill.title'),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(widget.med.name,
                  style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 16),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_pharmacies.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    context.tr('refill.noPharmacies'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.warning),
                  ),
                )
              else ...[
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    labelText: context.tr('refill.searchPharmacy'),
                    prefixIcon: const Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v.trim()),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilterChip(
                      label: Text(context.tr('refill.filter24h')),
                      selected: _only24h,
                      onSelected: (v) => setState(() => _only24h = v),
                    ),
                    FilterChip(
                      label: Text(context.tr('refill.filterDelivery')),
                      selected: _onlyDelivery,
                      onSelected: (v) => setState(() => _onlyDelivery = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _pharmacyId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: context.tr('refill.pharmacy'),
                    prefixIcon: const Icon(Icons.local_pharmacy_outlined),
                  ),
                  items: filtered
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                              p.locationLabel.isEmpty
                                  ? p.pharmacyName
                                  : '${p.pharmacyName} — ${p.locationLabel}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _pharmacyId = v),
                  validator: (v) =>
                      v == null ? context.tr('common.required') : null,
                ),
                const SizedBox(height: 12),
                Text(context.tr('refill.fulfillment'),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                SegmentedButton<String>(
                  segments: [
                    ButtonSegment(
                        value: 'PICKUP',
                        icon: const Icon(Icons.storefront_outlined, size: 18),
                        label: Text(context.tr('refill.pickup'))),
                    ButtonSegment(
                        value: 'DELIVERY',
                        icon:
                            const Icon(Icons.local_shipping_outlined, size: 18),
                        label: Text(context.tr('refill.delivery'))),
                  ],
                  selected: {_fulfillment},
                  onSelectionChanged: (s) =>
                      setState(() => _fulfillment = s.first),
                ),
                const SizedBox(height: 12),
                DefaultFormField(
                  controller: _quantity,
                  label: context.tr('refill.quantity'),
                  keyboardType: TextInputType.number,
                  validator: (v) => (int.tryParse(v ?? '0') ?? 0) < 1
                      ? context.tr('common.required')
                      : null,
                ),
                if (_fulfillment == 'DELIVERY') ...[
                  const SizedBox(height: 12),
                  DefaultFormField(
                    controller: _street,
                    label: context.tr('refill.street'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('common.required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DefaultFormField(
                    controller: _city,
                    label: context.tr('refill.city'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('common.required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  DefaultFormField(
                    controller: _zip,
                    label: context.tr('refill.zip'),
                    keyboardType: TextInputType.number,
                  ),
                ],
                const SizedBox(height: 16),
                DefaultButton(
                  label: context.tr('refill.submit'),
                  loading: _sending,
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;
                    setState(() => _sending = true);
                    final nav = Navigator.of(context);
                    final errMessenger = ScaffoldMessenger.of(context);
                    final successMsg = context.tr('refill.sent');
                    final failMsg = context.tr('refill.fail');
                    final address = _fulfillment == 'DELIVERY'
                        ? {
                            'street': _street.text.trim(),
                            'city': _city.text.trim(),
                            if (_zip.text.trim().isNotEmpty)
                              'zipCode': _zip.text.trim(),
                          }
                        : null;
                    try {
                      if (address != null) {
                        await CacheHelper.setSavedDeliveryAddress(
                            jsonEncode(address));
                      }
                      await _refillService.createRefill(
                        medicationId: widget.med.id,
                        targetPharmacyId: _pharmacyId!,
                        quantityRequested: int.tryParse(_quantity.text) ?? 1,
                        fulfillmentType: _fulfillment,
                        deliveryAddress: address,
                        patientId: widget.patientId,
                      );
                      AnalyticsService.instance
                          .log(AnalyticsService.refillRequested);
                      if (mounted) nav.pop();
                      widget.messenger
                          .showSnackBar(SnackBar(content: Text(successMsg)));
                    } catch (_) {
                      if (mounted) {
                        setState(() => _sending = false);
                        errMessenger
                            .showSnackBar(SnackBar(content: Text(failMsg)));
                      }
                    }
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared refill orders history dialog with visual status timeline & cancel.
Future<void> showRefillOrdersDialog(
  BuildContext context, {
  String? patientId,
}) async {
  final service = RefillService();
  var orders = await service
      .listRefills(patientId: patientId)
      .catchError((_) => <RefillOrderModel>[]);

  if (!context.mounted) return;
  await showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(context.tr('refill.myOrders')),
        content: SizedBox(
          width: double.maxFinite,
          child: orders.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    context.tr('refill.ordersEmpty'),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: orders.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (_, i) {
                    final o = orders[i];
                    final statusColor = switch (o.orderStatus) {
                      'COMPLETED' => AppColors.success,
                      'REJECTED' => AppColors.danger,
                      _ => AppColors.info,
                    };
                    final stepIndex = switch (o.orderStatus) {
                      'SUBMITTED' => 0,
                      'APPROVED' => 1,
                      'DISPENSED' || 'READY_FOR_PICKUP' => 2,
                      'COMPLETED' => 3,
                      _ => -1,
                    };
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.medication_outlined, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(o.medicationName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                            Chip(
                              label: Text(
                                context.tr('refill.status.${o.orderStatus}'),
                                style: TextStyle(
                                    fontSize: 11, color: statusColor),
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        Text(
                          '${o.pharmacyName} — ${context.tr('refill.quantity')}: ${o.quantityRequested}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (stepIndex >= 0) ...[
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: (stepIndex + 1) / 4,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(4),
                            color: statusColor,
                          ),
                        ],
                        if (o.isSubmitted && patientId == null)
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed: () async {
                                try {
                                  await service.cancelRefill(o.id);
                                  orders = await service.listRefills();
                                  if (dialogContext.mounted) {
                                    setDialogState(() {});
                                  }
                                } catch (_) {}
                              },
                              child: Text(context.tr('refill.cancelOrder'),
                                  style: const TextStyle(
                                      color: AppColors.danger, fontSize: 12)),
                            ),
                          ),
                      ],
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.tr('common.ok')),
          ),
        ],
      ),
    ),
  );
}
