import '../shared/network/local/cache_helper.dart';

bool _isEnLocale() {
  try {
    return CacheHelper.getLocale() == 'en';
  } catch (_) {
    return false;
  }
}

/// Refill orders + the pharmacy directory (backend: /medications/refills,
/// /profiles/pharmacists).
class RefillOrderModel {
  final String id;
  final String medicationId;
  final String medicationName;
  final String pharmacyId;
  final String pharmacyName;
  final String orderStatus; // SUBMITTED | APPROVED | DISPENSED | READY_FOR_PICKUP | COMPLETED | REJECTED
  final String fulfillmentType; // PICKUP | DELIVERY
  final int quantityRequested;
  final DateTime? createdAt;

  const RefillOrderModel({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.pharmacyId,
    required this.pharmacyName,
    required this.orderStatus,
    required this.fulfillmentType,
    required this.quantityRequested,
    this.createdAt,
  });

  factory RefillOrderModel.fromJson(Map<String, dynamic> json) {
    final med = json['medicationId'];
    final medMap = med is Map ? med : const <String, dynamic>{};
    final pharmacy = json['targetPharmacyId'];
    final phMap = pharmacy is Map ? pharmacy : const <String, dynamic>{};
    final isEn = _isEnLocale();
    return RefillOrderModel(
      id: (json['_id'] ?? '').toString(),
      medicationId: (medMap['_id'] ?? med ?? '').toString(),
      medicationName:
          (medMap['name'] ?? (isEn ? 'Medication' : 'دواء')).toString(),
      pharmacyId: (phMap['_id'] ?? pharmacy ?? '').toString(),
      pharmacyName:
          (phMap['pharmacyName'] ?? (isEn ? 'Pharmacy' : 'صيدلية')).toString(),
      orderStatus: (json['orderStatus'] ?? 'SUBMITTED').toString(),
      fulfillmentType: (json['fulfillmentType'] ?? 'PICKUP').toString(),
      quantityRequested: (json['quantityRequested'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  bool get isSubmitted => orderStatus == 'SUBMITTED';
  bool get isActive =>
      orderStatus == 'SUBMITTED' || orderStatus == 'APPROVED' ||
      orderStatus == 'DISPENSED' || orderStatus == 'READY_FOR_PICKUP';
}

/// Active pharmacy entry (public-safe fields only).
class PharmacyModel {
  final String id;
  final String pharmacyName;
  final String? governorate;
  final String? city;
  final String? phone;
  final bool is24Hours;
  final bool offersDelivery;

  const PharmacyModel({
    required this.id,
    required this.pharmacyName,
    this.governorate,
    this.city,
    this.phone,
    this.is24Hours = false,
    this.offersDelivery = true,
  });

  factory PharmacyModel.fromJson(Map<String, dynamic> json) {
    final address = json['address'];
    final addrMap = address is Map ? address : const <String, dynamic>{};
    return PharmacyModel(
      id: (json['_id'] ?? '').toString(),
      pharmacyName:
          (json['pharmacyName'] ?? (_isEnLocale() ? 'Pharmacy' : 'صيدلية'))
              .toString(),
      governorate: addrMap['governorate']?.toString(),
      city: addrMap['city']?.toString(),
      phone: json['pharmacyPhone']?.toString(),
      is24Hours: json['is24Hours'] as bool? ?? false,
      offersDelivery: json['offersDelivery'] as bool? ?? true,
    );
  }

  String get locationLabel {
    final parts = [city, governorate].where((s) => s != null && s.isNotEmpty);
    return parts.isEmpty ? '' : parts.join(_isEnLocale() ? ', ' : '، ');
  }
}
