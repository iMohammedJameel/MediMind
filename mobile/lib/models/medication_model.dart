import '../shared/components/constants.dart';

/// Medication — a patient's medication entry.
class MedicationModel {
  final String id;
  final String name;
  final bool isActive;
  final int dosesPerDay;
  final bool isChronic;
  /// "HH:MM" from the server — the edit sheet MUST prefill with this,
  /// otherwise saving an edit silently resets the dose time.
  final String firstDoseTime;
  /// Custom per-slot times (e.g. `['08:00', '14:00', '21:00']`) when set.
  final List<String> timesOfDay;
  /// Remaining inventory, when the server reports it.
  final int? inventoryQuantity;
  /// Low-stock threshold — at/below it the refill CTA appears.
  final int? refillThreshold;
  /// Size of one dose (used to suggest refill quantity).
  final double? doseAmount;
  /// Hosted medication photo (uploads module), when present.
  final String? imageUrl;
  final String? formType;
  /// Scheduling frequency: DAILY | WEEKLY | AS_NEEDED (PRN). As-needed
  /// meds get no scheduled time slots — the Today screen shows them as
  /// quick-log buttons instead.
  final String frequency;
  final String relationToMeals;
  final String notes;
  final DateTime? expirationDate;

  const MedicationModel({
    required this.id,
    required this.name,
    required this.isActive,
    required this.dosesPerDay,
    required this.isChronic,
    this.firstDoseTime = '08:00',
    this.timesOfDay = const [],
    this.inventoryQuantity,
    this.refillThreshold,
    this.doseAmount,
    this.imageUrl,
    this.formType,
    this.frequency = 'DAILY',
    this.relationToMeals = 'NONE',
    this.notes = '',
    this.expirationDate,
  });

  /// Fully qualified image URL resolved against `AppConstants.apiBaseUrl`.
  String? get resolvedImageUrl => AppConstants.resolveMediaUrl(imageUrl);

  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    final sched = json['schedule'] is Map ? json['schedule'] as Map : const {};
    final inv = json['inventory'] is Map ? json['inventory'] as Map : const {};
    final inst = json['instructions'] is Map ? json['instructions'] as Map : const {};
    final rawTimes = sched['timesOfDay'];
    final parsedTimes = rawTimes is List
        ? rawTimes.map((e) => e.toString()).where((s) => s.isNotEmpty).toList()
        : const <String>[];
    return MedicationModel(
      id: (json['_id'] ?? json['medicationId'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      isActive: json['isActive'] as bool? ?? true,
      dosesPerDay: (sched['dosesPerDay'] as num?)?.toInt() ?? 1,
      isChronic: json['isChronic'] as bool? ?? false,
      firstDoseTime: (sched['firstDoseTime'] ?? '08:00').toString(),
      timesOfDay: parsedTimes,
      inventoryQuantity: (inv['currentQuantity'] as num?)?.toInt(),
      refillThreshold: (inv['refillThreshold'] as num?)?.toInt(),
      doseAmount: (inv['doseAmount'] as num?)?.toDouble(),
      imageUrl: (json['imageURL'] ?? json['imageUrl'])?.toString(),
      formType: json['formType']?.toString(),
      frequency: (sched['frequency'] ?? 'DAILY').toString(),
      relationToMeals:
          (inst['relationToMeals'] ?? sched['relationToMeals'] ?? 'NONE')
              .toString(),
      notes: (inst['notes'] ?? '').toString(),
      expirationDate: json['expirationDate'] != null
          ? DateTime.tryParse(json['expirationDate'].toString())
          : null,
    );
  }

  /// As-needed (PRN) medication — logged ad-hoc, never scheduled.
  bool get isAsNeeded => frequency == 'AS_NEEDED';

  /// True when remaining stock is at/below the low-stock threshold.
  bool get isLowStock {
    final qty = inventoryQuantity;
    final threshold = refillThreshold ?? 5;
    return qty != null && qty <= threshold;
  }

  Map<String, dynamic> toJson() => {
        '_id': id,
        'name': name,
        'isActive': isActive,
        'isChronic': isChronic,
        if (formType != null) 'formType': formType,
        if (imageUrl != null) 'imageURL': imageUrl,
        if (expirationDate != null)
          'expirationDate': expirationDate!.toIso8601String(),
        'schedule': {
          'frequency': frequency,
          'dosesPerDay': dosesPerDay,
          'firstDoseTime': firstDoseTime,
          if (timesOfDay.isNotEmpty) 'timesOfDay': timesOfDay,
        },
        'instructions': {
          'relationToMeals': relationToMeals,
          if (notes.isNotEmpty) 'notes': notes,
        },
        if (inventoryQuantity != null || refillThreshold != null || doseAmount != null)
          'inventory': {
            if (inventoryQuantity != null) 'currentQuantity': inventoryQuantity,
            if (refillThreshold != null) 'refillThreshold': refillThreshold,
            if (doseAmount != null) 'doseAmount': doseAmount,
          },
      };

  /// Parsed [firstDoseTime] for TimePicker prefill.
  (int, int) get firstDoseParts {
    final parts = firstDoseTime.split(':');
    return (
      int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8,
      int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
  }
}

/// One extracted medication entry from an OCR prescription scan.
class ScannedMedicationItem {
  final String name;
  final String formType;
  final int dosesPerDay;
  final String frequency;
  final double confidence;

  const ScannedMedicationItem({
    required this.name,
    this.formType = 'TABLET',
    this.dosesPerDay = 1,
    this.frequency = 'DAILY',
    this.confidence = 0,
  });

  factory ScannedMedicationItem.fromJson(Map<String, dynamic> json) {
    final raw = json['confidenceScore'] ?? json['confidence'] ?? 0;
    return ScannedMedicationItem(
      name: (json['name'] ?? '').toString(),
      formType: (json['formType'] ?? 'TABLET').toString(),
      dosesPerDay: (json['dosesPerDay'] as num?)?.toInt() ?? 1,
      frequency: (json['frequency'] ?? 'DAILY').toString(),
      confidence: raw is num ? raw.toDouble() : (double.tryParse('$raw') ?? 0),
    );
  }

  bool get isConfident => confidence >= 0.9;

  ScannedMedicationItem copyWith({
    String? name,
    String? formType,
    int? dosesPerDay,
    String? frequency,
  }) =>
      ScannedMedicationItem(
        name: name ?? this.name,
        formType: formType ?? this.formType,
        dosesPerDay: dosesPerDay ?? this.dosesPerDay,
        frequency: frequency ?? this.frequency,
        confidence: confidence,
      );
}

/// OCR scan result returned by POST /medications/scan (single or multi-med).
class ScanResultModel {
  final String? name;
  final String? formType;
  final double confidence;
  final List<ScannedMedicationItem> medications;

  const ScanResultModel({
    required this.name,
    required this.formType,
    required this.confidence,
    this.medications = const [],
  });

  factory ScanResultModel.fromJson(Map<String, dynamic> json) {
    final raw = json['confidenceScore'] ?? json['confidence'] ?? 0;
    final conf = raw is num ? raw.toDouble() : (double.tryParse('$raw') ?? 0);
    final rawList = json['medications'];
    final items = rawList is List
        ? rawList
            .whereType<Map>()
            .map((e) => ScannedMedicationItem.fromJson(e.cast<String, dynamic>()))
            .where((m) => m.name.trim().isNotEmpty)
            .toList()
        : <ScannedMedicationItem>[];
    final singleName = json['name']?.toString();
    final singleForm = json['formType']?.toString();
    if (items.isEmpty && singleName != null && singleName.trim().isNotEmpty) {
      items.add(ScannedMedicationItem(
        name: singleName.trim(),
        formType: singleForm ?? 'TABLET',
        confidence: conf,
      ));
    }
    return ScanResultModel(
      name: singleName ?? (items.isNotEmpty ? items.first.name : null),
      formType: singleForm ?? (items.isNotEmpty ? items.first.formType : null),
      confidence: conf > 0 ? conf : (items.isNotEmpty ? items.first.confidence : 0),
      medications: items,
    );
  }

  bool get isConfident => confidence >= 0.9;
}

/// Drug-interaction warning returned when creating a medication.
class InteractionWarningModel {
  final String severity; // HIGH | MODERATE
  final String effect;
  final String effectAr;
  final String recommendation;
  final String recommendationAr;

  const InteractionWarningModel({
    required this.severity,
    required this.effect,
    required this.effectAr,
    required this.recommendation,
    this.recommendationAr = '',
  });

  factory InteractionWarningModel.fromJson(Map<String, dynamic> json) =>
      InteractionWarningModel(
        severity: (json['severity'] ?? 'MODERATE').toString(),
        effect: (json['effect'] ?? '').toString(),
        effectAr: (json['effectAr'] ?? json['effect'] ?? '').toString(),
        recommendation: (json['recommendation'] ?? '').toString(),
        recommendationAr:
            (json['recommendationAr'] ?? json['recommendation'] ?? '')
                .toString(),
      );

  String effectFor(String locale) =>
      locale == 'en' ? (effect.isNotEmpty ? effect : effectAr) : (effectAr.isNotEmpty ? effectAr : effect);

  String recommendationFor(String locale) => locale == 'en'
      ? (recommendation.isNotEmpty ? recommendation : recommendationAr)
      : (recommendationAr.isNotEmpty ? recommendationAr : recommendation);

  bool get isHigh => severity == 'HIGH';
}

/// Caregiver↔patient relationship (covers both perspectives).
class RelationshipModel {
  final String id;
  final String patientId;
  final String patientName;
  final String? patientPhone;
  final String? emergencyPhone;
  final String caregiverId;
  final String caregiverName;
  final String relation;
  final String status;

  const RelationshipModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.patientPhone,
    this.emergencyPhone,
    required this.caregiverId,
    required this.caregiverName,
    required this.relation,
    required this.status,
  });

  factory RelationshipModel.fromJson(Map<String, dynamic> json) {
    final patient = json['patientId'];
    final patientMap = patient is Map ? patient : const <String, dynamic>{};
    final caregiver = json['caregiverId'];
    final caregiverMap = caregiver is Map ? caregiver : const <String, dynamic>{};
    return RelationshipModel(
      id: (json['_id'] ?? '').toString(),
      patientId: (patientMap['_id'] ?? patient ?? '').toString(),
      patientName:
          '${patientMap['firstName'] ?? ''} ${patientMap['lastName'] ?? ''}'.trim(),
      patientPhone: patientMap['phone']?.toString(),
      emergencyPhone: patientMap['emergencyPhone']?.toString(),
      caregiverId: (caregiverMap['_id'] ?? caregiver ?? '').toString(),
      caregiverName:
          '${caregiverMap['firstName'] ?? ''} ${caregiverMap['lastName'] ?? ''}'.trim(),
      relation: (json['relation'] ?? '').toString(),
      status: (json['status'] ?? 'PENDING').toString(),
    );
  }

  bool get isAccepted => status == 'ACCEPTED';
  bool get isPending => status == 'PENDING';
  bool get isRejected => status == 'REJECTED';

  /// The "other party" name for whichever side of the link is viewing.
  String get otherPartyName =>
      caregiverName.isNotEmpty ? caregiverName : patientName;
}
