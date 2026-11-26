import 'package:flutter_test/flutter_test.dart';
import 'package:medimind/models/dose_event_model.dart';
import 'package:medimind/models/medication_model.dart';
import 'package:medimind/modules/login/cubit/login_cubit.dart';
import 'package:medimind/modules/login/cubit/login_states.dart';
import 'package:medimind/modules/register/cubit/register_states.dart';
import 'package:medimind/modules/today/cubit/today_states.dart';
import 'package:medimind/modules/medications/cubit/medications_states.dart';
import 'package:medimind/modules/register/cubit/register_cubit.dart';
import 'package:medimind/modules/today/cubit/today_cubit.dart';
import 'package:medimind/modules/medications/cubit/medications_cubit.dart';
import 'package:medimind/services/auth_service.dart';
import 'package:medimind/services/doses_service.dart';
import 'package:medimind/services/medications_service.dart';
import 'package:medimind/modules/adherence/cubit/adherence_cubit.dart';
import 'package:medimind/modules/adherence/cubit/adherence_states.dart';
import 'package:medimind/modules/alarm/cubit/alarm_cubit.dart';
import 'package:medimind/modules/alarm/cubit/alarm_states.dart';
import 'package:medimind/modules/patient_detail/cubit/patient_detail_cubit.dart';
import 'package:medimind/modules/patient_detail/cubit/patient_detail_states.dart';
import 'package:medimind/shared/network/local/cache_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---- Fakes ----

class FakeAuthService implements AuthService {
  FakeAuthService({this.role = 'PATIENT', this.shouldFail = false});

  final String role;
  final bool shouldFail;
  String? lastEmail;
  String? lastPhone;

  @override
  Future<String> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    lastEmail = email;
    lastPhone = phone;
    if (shouldFail) throw Exception('401');
    return role;
  }

  @override
  Future<String> registerPatient({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String countryCode,
    required String phone,
  }) async {
    if (shouldFail) throw Exception('400');
    return 'PATIENT';
  }

  @override
  Future<String> registerFamilyCaregiver({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String countryCode,
    required String phone,
  }) async {
    if (shouldFail) throw Exception('400');
    return 'FAMILY_CAREGIVER';
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> requestPasswordReset(String identifier) async {
    if (shouldFail) throw Exception('404');
  }

  @override
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String newPassword,
  }) async {
    if (shouldFail) throw Exception('400');
  }
}

class FakeDosesService implements DosesService {
  FakeDosesService({bool shouldFail = false})
      : shouldFailLoad = shouldFail,
        shouldFailConfirm = shouldFail;

  FakeDosesService.failConfirm()
      : shouldFailLoad = false,
        shouldFailConfirm = true;

  final bool shouldFailLoad;
  final bool shouldFailConfirm;

  final List<String> confirmed = [];
  final List<String> skipped = [];

  List<DoseEventModel> doses = [
    DoseEventModel(
        id: 'd1', medicationId: 'm1', medicationName: 'Glucophage',
        scheduledFor: DateTime(2026, 8, 16, 8), status: 'PENDING'),
    DoseEventModel(
        id: 'd2', medicationId: 'm1', medicationName: 'Glucophage',
        scheduledFor: DateTime(2026, 8, 16, 20), status: 'PENDING'),
  ];

  @override
  Future<List<DoseEventModel>> todaySchedule({String? patientId}) async {
    if (shouldFailLoad) throw Exception('network');
    return doses;
  }

  @override
  Future<List<DoseEventModel>> rangeSchedule(
      {required int days, String? patientId}) async {
    if (shouldFailLoad) throw Exception('network');
    return doses;
  }

  @override
  Future<void> confirmDose(String doseEventId) async {
    if (shouldFailConfirm) throw Exception('500');
    confirmed.add(doseEventId);
    doses = doses
        .map((d) => d.id == doseEventId ? d.copyWith(status: 'TAKEN') : d)
        .toList();
  }

  @override
  Future<void> skipDose(String doseEventId) async {
    skipped.add(doseEventId);
    doses = doses
        .map((d) => d.id == doseEventId ? d.copyWith(status: 'SKIPPED') : d)
        .toList();
  }

  @override
  Future<DoseEventModel> logExtraDose(String medicationId) async {
    final dose = DoseEventModel(
        id: 'extra-$medicationId',
        medicationId: medicationId,
        medicationName: 'PRN',
        scheduledFor: DateTime.now(),
        status: 'TAKEN');
    doses = [...doses, dose];
    return dose;
  }

  @override
  Future<List<DoseEventModel>> rangeScheduleBetween({
    required DateTime from,
    required DateTime to,
    String? patientId,
  }) async {
    if (shouldFailLoad) throw Exception('network');
    return doses;
  }
}

class FakeMedicationsService implements MedicationsService {
  final List<InteractionWarningModel> warningsToReturn;

  FakeMedicationsService([this.warningsToReturn = const []]);

  Map<String, dynamic>? lastPayload;

  @override
  Future<List<InteractionWarningModel>> createMedication(
      Map<String, dynamic> payload) async {
    lastPayload = payload;
    return warningsToReturn;
  }

  @override
  Future<List<MedicationModel>> listMedications({String? patientId}) async => [
        MedicationModel.fromJson(
            {'_id': 'm1', 'name': 'Panadol', 'isActive': true, 'schedule': {}}),
      ];

  @override
  Future<ScanResultModel> scanPrescription(String imageBase64) async =>
      ScanResultModel.fromJson(
          {'name': 'Augmentin', 'formType': 'TABLET', 'confidenceScore': 0.95});

  final List<String> updated = [];
  final List<String> deleted = [];

  @override
  Future<void> updateMedication(String id, Map<String, dynamic> payload) async {
    updated.add(id);
  }

  @override
  Future<void> deleteMedication(String id) async {
    deleted.add(id);
  }
}

// ---- Tests ----

void main() {
  group('LoginCubit', () {
    test('empty credentials -> error', () async {
      final cubit = LoginCubit(FakeAuthService());
      await cubit.login(email: '', password: '');
      expect(cubit.state, isA<LoginError>());
    });

    test('success emits Loading then Success with role', () async {
      final cubit = LoginCubit(FakeAuthService(role: 'FAMILY_CAREGIVER'));
      final states = <LoginStates>[];
      cubit.stream.listen(states.add);
      await cubit.login(email: 'a@b.com', password: 'pass1234');
      await Future<void>.delayed(Duration.zero);
      expect(states, isA<List<LoginStates>>());
      expect(cubit.state, isA<LoginSuccess>());
      expect((cubit.state as LoginSuccess).role, 'FAMILY_CAREGIVER');
    });

    test('failure -> LoginError', () async {
      final cubit = LoginCubit(FakeAuthService(shouldFail: true));
      await cubit.login(email: 'a@b.com', password: 'wrong');
      expect(cubit.state, isA<LoginError>());
    });

    test('phone method: empty phone -> error, filled phone logs in', () async {
      final service = FakeAuthService(role: 'PATIENT');
      final cubit = LoginCubit(service);
      cubit.setMethod(byPhone: true);
      await cubit.login(phone: '', password: 'x');
      expect(cubit.state, isA<LoginError>());

      await cubit.login(phone: '01012345678', password: 'pass1234');
      expect(cubit.state, isA<LoginSuccess>());
      expect(service.lastPhone, '01012345678');
      expect(service.lastEmail, isNull);
    });
  });

  group('RegisterCubit', () {
    test('invalid input -> error without calling service', () async {
      final cubit = RegisterCubit(FakeAuthService());
      await cubit.register(
          firstName: 'A', lastName: 'B', email: 'bad',
          password: '123', phone: '123');
      expect(cubit.state, isA<RegisterError>());
    });

    test('valid input -> success (carries role for routing)', () async {
      final cubit = RegisterCubit(FakeAuthService());
      await cubit.register(
          firstName: 'Ahmed', lastName: 'Ali', email: 'a@b.com',
          password: 'password1', phone: '1012345678');
      expect(cubit.state, isA<RegisterSuccess>());
      expect((cubit.state as RegisterSuccess).role, 'PATIENT');
    });
  });

  group('TodayCubit', () {
    test('loads doses and confirms locally', () async {
      final service = FakeDosesService();
      final cubit = TodayCubit(service);

      await cubit.loadSchedule();
      expect(cubit.state, isA<TodayLoaded>());
      expect(cubit.doses.length, 2);

      await cubit.confirmDose('d1');
      expect(service.confirmed, ['d1']);
      final dose = cubit.doses.firstWhere((d) => d.id == 'd1');
      expect(dose.status, 'TAKEN');
      expect(cubit.state, isA<TodayLoaded>());
    });

    test('confirm failure keeps list and surfaces error', () async {
      final service = FakeDosesService.failConfirm();
      final cubit = TodayCubit(service);
      await cubit.loadSchedule();
      await cubit.confirmDose('d1');
      expect(cubit.state, isA<TodayLoaded>());
      expect(cubit.doses.first.status, 'PENDING');
    });

    test('load failure -> TodayError', () async {
      final cubit = TodayCubit(FakeDosesService(shouldFail: true));
      await cubit.loadSchedule();
      expect(cubit.state, isA<TodayError>());
    });
  });

  group('MedicationsCubit', () {
    test('create with interactions surfaces warnings', () async {
      final service = FakeMedicationsService([
        InteractionWarningModel.fromJson({
          'severity': 'HIGH',
          'effect': 'Bleeding risk',
          'effectAr': 'خطر نزيف',
          'recommendation': 'Consult doctor',
        }),
      ]);
      final cubit = MedicationsCubit(service);
      await cubit.createMedication(
          name: 'Warfarin',
          dosesPerDay: 2,
          firstDoseTime: '08:00',
          timesOfDay: ['08:00', '20:00'],
          isChronic: false);

      // Ends on the reloaded list state, after passing through MedicationSaved
      expect(cubit.state, isA<MedicationsLoaded>());
      expect(service.lastPayload, isNotNull);
      expect(service.lastPayload!['name'], 'Warfarin');
      expect(
          (service.lastPayload!['schedule'] as Map)['timesOfDay'],
          ['08:00', '20:00']);
    });

    test('empty name -> save error', () async {
      final cubit = MedicationsCubit(FakeMedicationsService());
      await cubit.createMedication(
          name: '  ', dosesPerDay: 1,
          firstDoseTime: '08:00', isChronic: false);
      expect(cubit.state, isA<MedicationSaveError>());
    });

    test('update calls service and reloads list', () async {
      final service = FakeMedicationsService();
      final cubit = MedicationsCubit(service);
      await cubit.loadMedications();
      await cubit.updateMedication('m1', dosesPerDay: 2, isActive: false);
      expect(service.updated, ['m1']);
      expect(cubit.state, isA<MedicationsLoaded>());
    });

    test('delete removes optimistically and confirms', () async {
      final service = FakeMedicationsService();
      final cubit = MedicationsCubit(service);
      await cubit.loadMedications();
      await cubit.deleteMedication('m1');
      expect(service.deleted, ['m1']);
      expect(cubit.medications.where((m) => m.id == 'm1'), isEmpty);
    });
  });

  group('AdherenceCubit', () {
    test('week range uses rangeSchedule', () async {
      final service = FakeDosesService();
      final cubit = AdherenceCubit(service);
      await cubit.setRange(AdherenceRange.week);
      expect(cubit.state, isA<AdherenceLoaded>());
      expect((cubit.state as AdherenceLoaded).range, AdherenceRange.week);
    });
  });

  group('PatientDetailCubit', () {
    test('loads doses, medications, and 7-day adherence', () async {
      final cubit = PatientDetailCubit(
          'p1', FakeDosesService(), FakeMedicationsService());
      await cubit.load();
      expect(cubit.state, isA<PatientDetailLoaded>());
      final loaded = cubit.state as PatientDetailLoaded;
      expect(loaded.doses.length, 2);
      expect(loaded.medications.length, 1);
    });
  });

  group('AlarmCubit.resolveDose & snooze', () {
    test('returns null when dose is missing from network and cache', () async {
      SharedPreferences.setMockInitialValues(const {});
      await CacheHelper.init();
      final result = await AlarmCubit.resolveDose('nonexistent-dose-id');
      expect(result, isNull);
    });

    test('snooze keeps dose PENDING and never calls confirmDose', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(const {});
      await CacheHelper.init();
      final service = FakeDosesService();
      final dose = DoseEventModel(
        id: 'd-snooze',
        medicationId: 'm1',
        medicationName: 'TestMed',
        scheduledFor: DateTime.now(),
        status: 'PENDING',
      );
      final cubit = AlarmCubit(dose, dosesService: service);
      await cubit.snooze(minutes: 5);
      expect(service.confirmed, isEmpty);
      expect(service.skipped, isEmpty);
      expect(cubit.state, isA<AlarmDone>());
      expect((cubit.state as AlarmDone).dose.status, 'PENDING');
      await cubit.close();
    });
  });
}
