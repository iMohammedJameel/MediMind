import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/models/dose_event_model.dart';
import 'package:medimind/models/medication_model.dart';
import 'package:medimind/shared/components/constants.dart';
import 'package:medimind/shared/utils/validators.dart';

DoseEventModel _dose(String id, String status) => DoseEventModel(
      id: id,
      medicationId: 'm',
      medicationName: 'a',
      scheduledFor: DateTime(2026),
      status: status,
    );

void main() {
  group('AdherenceSummary.percentDueSoFar', () {
    final morning = DateTime(2026, 8, 21, 8, 0);
    final evening = DateTime(2026, 8, 21, 20, 0);
    final noon = DateTime(2026, 8, 21, 12, 0);

    DoseEventModel dose(DateTime t, String status) => DoseEventModel(
        id: 'x', medicationId: 'm', medicationName: 'n',
        scheduledFor: t, status: status);

    test('future doses excluded from denominator', () {
      final doses = [dose(morning, 'TAKEN'), dose(evening, 'PENDING')];
      final s = AdherenceSummary.fromDoses(doses);
      // Old percent: 1/2 = 0.5 showing 50% even before evening is due...
      // due-so-far at noon: only morning counts -> 100%.
      expect(s.percentDueSoFar(doses, noon), 1.0);
    });

    test('no doses due yet -> 0', () {
      final doses = [dose(evening, 'PENDING')];
      final s = AdherenceSummary.fromDoses(doses);
      expect(s.percentDueSoFar(doses, noon), 0.0);
    });
  });

  group('MedicationModel server fields', () {
    test('parses firstDoseTime and inventory', () {
      final m = MedicationModel.fromJson({
        '_id': 'm1', 'name': 'X', 'isActive': true,
        'schedule': {'dosesPerDay': 3, 'firstDoseTime': '14:30'},
        'inventory': {'currentQuantity': 12},
      });
      expect(m.firstDoseTime, '14:30');
      expect(m.inventoryQuantity, 12);
      expect(m.firstDoseParts, (14, 30));
    });
  });

  group('DoseEventModel', () {
    test('parses flat backend JSON', () {
      final dose = DoseEventModel.fromJson({
        'doseEventId': 'abc123',
        'medicationId': 'med456',
        'medicationName': 'Glucophage',
        'scheduledFor': '2026-08-16T08:00:00.000',
        'status': 'PENDING',
      });
      expect(dose.id, 'abc123');
      expect(dose.medicationName, 'Glucophage');
      expect(dose.status, 'PENDING');
      expect(dose.isPending, isTrue);
      expect(dose.timeLabel, '08:00');
      expect(dose.scheduledFor.isUtc, isFalse);
    });

    test('parses populated medication object', () {
      final dose = DoseEventModel.fromJson({
        '_id': 'd1',
        'medicationId': {'_id': 'm1', 'name': 'Concor'},
        'scheduledFor': '2026-08-16T20:30:00.000',
        'status': 'TAKEN',
      });
      expect(dose.medicationId, 'm1');
      expect(dose.medicationName, 'Concor');
      expect(dose.isTaken, isTrue);
      expect(dose.timeLabel, '20:30');
      expect(
        DoseEventModel.fromJson({
          'doseEventId': 'u1',
          'scheduledFor': '2026-08-16T08:00:00Z', // UTC input
        }).scheduledFor.isUtc,
        isFalse,
        reason: 'UTC server timestamps must convert to device-local',
      );
    });

    test('copyWith changes status only', () {
      final dose = _dose('x', 'PENDING');
      final updated = dose.copyWith(status: 'TAKEN');
      expect(updated.status, 'TAKEN');
      expect(updated.id, 'x');
      expect(updated.medicationName, 'a');
    });
  });

  group('AdherenceSummary', () {
    test('percent is taken/total', () {
      final doses = [
        _dose('1', 'TAKEN'),
        _dose('2', 'TAKEN'),
        _dose('3', 'MISSED'),
        _dose('4', 'LATE'),
      ];
      final s = AdherenceSummary.fromDoses(doses);
      expect(s.total, 4);
      expect(s.taken, 2);
      expect(s.missed, 1);
      expect(s.late, 1);
      expect(s.percent, 0.5);
    });

    test('empty list gives 0 percent', () {
      final s = AdherenceSummary.fromDoses(const []);
      expect(s.percent, 0);
      expect(s.total, 0);
    });
  });

  group('ScanResultModel', () {
    test('parses confidenceScore', () {
      final r = ScanResultModel.fromJson({
        'name': 'Amoxicillin',
        'formType': 'CAPSULE',
        'confidenceScore': 0.96,
      });
      expect(r.name, 'Amoxicillin');
      expect(r.confidence, 0.96);
      expect(r.isConfident, isTrue);
      expect(r.medications.length, 1);
    });

    test('parses multi-medication prescription payload', () {
      final r = ScanResultModel.fromJson({
        'name': 'Concor 5mg',
        'confidenceScore': 0.97,
        'medications': [
          {'name': 'Concor 5mg', 'dosesPerDay': 1, 'confidenceScore': 0.97},
          {'name': 'Panadol', 'dosesPerDay': 2, 'frequency': 'AS_NEEDED', 'confidenceScore': 0.91},
        ],
      });
      expect(r.medications.length, 2);
      expect(r.medications[1].name, 'Panadol');
      expect(r.medications[1].frequency, 'AS_NEEDED');
    });

    test('low confidence flagged', () {
      final r = ScanResultModel.fromJson({'confidence': 0.7});
      expect(r.isConfident, isFalse);
    });
  });

  group('Media URL resolution', () {
    test('resolves relative /uploads path against backend origin', () {
      final resolved = AppConstants.resolveMediaUrl('/uploads/med_1.jpg');
      expect(resolved, isNotNull);
      expect(resolved!.endsWith('/uploads/med_1.jpg'), isTrue);
      expect(resolved.contains('/api/v1'), isFalse);
      expect(
        AppConstants.resolveMediaUrl('https://cdn.example.com/a.jpg'),
        'https://cdn.example.com/a.jpg',
      );
    });
  });

  group('InteractionWarningModel locale helpers', () {
    test('picks English vs Arabic effect and recommendation', () {
      final w = InteractionWarningModel.fromJson({
        'severity': 'HIGH',
        'effect': 'Bleeding risk',
        'effectAr': 'خطر نزيف',
        'recommendation': 'Consult doctor',
        'recommendationAr': 'استشر طبيبك',
      });
      expect(w.effectFor('en'), 'Bleeding risk');
      expect(w.effectFor('ar'), 'خطر نزيف');
      expect(w.recommendationFor('en'), 'Consult doctor');
      expect(w.recommendationFor('ar'), 'استشر طبيبك');
    });
  });

  group('AppValidators', () {
    test('validates Egyptian phones and emails uniformly', () {
      expect(AppValidators.isValidEgyptianPhone('01012345678'), isTrue);
      expect(AppValidators.isValidEgyptianPhone('+201112345678'), isTrue);
      expect(AppValidators.isValidEgyptianPhone('12345'), isFalse);
      expect(AppValidators.isValidEmailOrPhone('user@medimind.app'), isTrue);
      expect(AppValidators.isValidEmailOrPhone('01512345678'), isTrue);
      expect(AppValidators.isValidEmailOrPhone('invalid'), isFalse);
    });
  });

  group('MedicationModel', () {
    test('parses schedule dosesPerDay', () {
      final m = MedicationModel.fromJson({
        '_id': 'm1',
        'name': 'Panadol',
        'isActive': true,
        'schedule': {'dosesPerDay': 3},
      });
      expect(m.dosesPerDay, 3);
      expect(m.name, 'Panadol');
      expect(m.isActive, isTrue);
    });
  });

  group('RelationshipModel', () {
    test('only ACCEPTED counts via isAccepted', () {
      final rel = RelationshipModel.fromJson({
        '_id': 'r1',
        'patientId': {'_id': 'p1', 'firstName': 'Ahmed', 'lastName': 'Ali'},
        'relation': 'son',
        'status': 'ACCEPTED',
      });
      expect(rel.isAccepted, isTrue);
      expect(rel.patientName, 'Ahmed Ali');
      expect(rel.patientId, 'p1');
    });
  });
}
