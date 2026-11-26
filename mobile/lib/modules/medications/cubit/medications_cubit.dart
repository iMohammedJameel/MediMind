import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/medication_model.dart';
import '../../../services/analytics_service.dart';
import '../../../services/doses_service.dart';
import '../../../services/local_notifications_service.dart';
import '../../../services/medications_service.dart';
import '../../../services/refill_service.dart';
import 'medications_states.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/utils/safe_emit.dart';

class MedicationsCubit extends Cubit<MedicationsStates>
    with SafeEmit<MedicationsStates> {
  final MedicationsService _medicationsService;

  MedicationsCubit([MedicationsService? service])
      : _medicationsService = service ?? MedicationsService(),
        super(const MedicationsInitial());

  List<MedicationModel> medications = [];
  Set<String> activeRefillMedIds = const {};

  Future<void> loadMedications() async {
    final hasCache = await _loadCachedMedications();
    if (hasCache && medications.isNotEmpty) {
      emit(MedicationsLoaded(medications, fromCache: true));
    } else {
      emit(const MedicationsLoading());
    }

    try {
      medications = await _medicationsService.listMedications();
      await _cacheMedications();
      await _loadActiveRefillsBestEffort();
      emit(MedicationsLoaded(medications, fromCache: false));
    } catch (e) {
      if (!hasCache || medications.isEmpty) {
        emit(MedicationsError(apiError(e, 'err.medsLoad')));
      }
    }
  }

  Future<void> _loadActiveRefillsBestEffort() async {
    try {
      final orders = await RefillService().listRefills();
      activeRefillMedIds =
          orders.where((o) => o.isActive).map((o) => o.medicationId).toSet();
    } catch (_) {
      // Best-effort badge — never blocks medications list.
    }
  }

  Future<void> createMedication({
    required String name,
    String formType = 'TABLET',
    String frequency = 'DAILY',
    required int dosesPerDay,
    required String firstDoseTime,
    List<String>? timesOfDay,
    required bool isChronic,
    int? durationDays,
    int initialQuantity = 30,
    double doseAmount = 1.0,
    int refillThreshold = 5,
    String relationToMeals = 'NONE',
    String notes = '',
    DateTime? expirationDate,
    String? imageUrl,
  }) async {
    if (name.trim().isEmpty || dosesPerDay < 1) {
      emit(const MedicationSaveError('err.medSaveValidation'));
      return;
    }
    emit(const MedicationSaving());
    try {
      final now = DateTime.now().toUtc();
      final exp = (expirationDate ?? DateTime.now().add(const Duration(days: 365))).toUtc();
      final days = durationDays ?? (isChronic ? 3650 : 7);

      final warnings = await _medicationsService.createMedication({
        'name': name.trim(),
        'formType': formType,
        'isChronic': isChronic,
        if (imageUrl != null && imageUrl.isNotEmpty) 'imageURL': imageUrl,
        'schedule': {
          'frequency': frequency,
          'dosesPerDay': dosesPerDay,
          'firstDoseTime': firstDoseTime,
          if (timesOfDay != null && timesOfDay.isNotEmpty) 'timesOfDay': timesOfDay,
          'startDate': now.toIso8601String(),
          if (!isChronic) 'endDate': now.add(Duration(days: days)).toIso8601String(),
        },
        'inventory': {
          'initialQuantity': initialQuantity,
          'currentQuantity': initialQuantity,
          'doseAmount': doseAmount,
          'refillThreshold': refillThreshold,
        },
        'instructions': {
          'relationToMeals': relationToMeals,
          'notes': notes.trim(),
        },
        'expirationDate': exp.toIso8601String(),
      });
      AnalyticsService.instance.log(AnalyticsService.medAdded,
          properties: {'frequency': frequency, 'formType': formType});
      emit(MedicationSaved(warnings));
      await loadMedications();
      await _syncTodayReminders();
    } catch (e) {
      emit(MedicationSaveError(apiError(e, 'err.medSave')));
    }
  }

  /// Partial update — editable fields: schedule (frequency, dosesPerDay,
  /// firstDoseTime, timesOfDay), inventory, instructions, formType, chronic, active.
  Future<void> updateMedication(
    String id, {
    String? formType,
    String? frequency,
    int? dosesPerDay,
    String? firstDoseTime,
    List<String>? timesOfDay,
    int? inventoryQuantity,
    int? refillThreshold,
    double? doseAmount,
    String? relationToMeals,
    String? notes,
    bool? isChronic,
    bool? isActive,
  }) async {
    emit(const MedicationSaving());
    try {
      final schedule = <String, dynamic>{
        if (frequency != null) 'frequency': frequency,
        if (dosesPerDay != null) 'dosesPerDay': dosesPerDay,
        if (firstDoseTime != null) 'firstDoseTime': firstDoseTime,
        if (timesOfDay != null && timesOfDay.isNotEmpty) 'timesOfDay': timesOfDay,
      };
      final inventory = <String, dynamic>{
        if (inventoryQuantity != null) 'currentQuantity': inventoryQuantity,
        if (refillThreshold != null) 'refillThreshold': refillThreshold,
        if (doseAmount != null) 'doseAmount': doseAmount,
      };
      final instructions = <String, dynamic>{
        if (relationToMeals != null) 'relationToMeals': relationToMeals,
        if (notes != null) 'notes': notes.trim(),
      };
      await _medicationsService.updateMedication(id, {
        if (formType != null) 'formType': formType,
        if (isChronic != null) 'isChronic': isChronic,
        if (schedule.isNotEmpty) 'schedule': schedule,
        if (inventory.isNotEmpty) 'inventory': inventory,
        if (instructions.isNotEmpty) 'instructions': instructions,
        if (isActive != null) 'isActive': isActive,
      });
      emit(const MedicationUpdated());
      await loadMedications();
      await _syncTodayReminders();
    } catch (e) {
      emit(MedicationSaveError(apiError(e, 'err.medUpdate')));
    }
  }

  Future<void> deleteMedication(String id) async {
    // Optimistic removal; reload confirms.
    medications = medications.where((m) => m.id != id).toList();
    emit(MedicationsLoaded(medications));
    try {
      await _medicationsService.deleteMedication(id);
      emit(const MedicationDeleted());
      await _syncTodayReminders();
    } catch (e) {
      emit(MedicationSaveError(apiError(e, 'err.medDelete')));
      await loadMedications();
    }
  }

  Future<void> _syncTodayReminders() async {
    try {
      if (!CacheHelper.getNotificationsEnabled()) return;
      await LocalNotificationsService.ensurePermissionsRequested();
      final doses = await DosesService().todaySchedule();
      await LocalNotificationsService.scheduleDoseReminders(doses);
    } catch (_) {}
  }

  Future<void> _cacheMedications() async {
    try {
      final encoded = medications.map((m) => m.toJson()).toList();
      final strings = encoded.map((m) => jsonEncode(m)).toList();
      await CacheHelper.setString(
        CacheHelper.cachedMedicationsKey,
        jsonEncode(strings),
      );
    } catch (_) {}
  }

  Future<bool> _loadCachedMedications() async {
    try {
      final raw = CacheHelper.getString(CacheHelper.cachedMedicationsKey);
      if (raw == null) return false;
      final strings = (jsonDecode(raw) as List).cast<String>();
      medications = strings
          .map((s) => MedicationModel.fromJson(jsonDecode(s)))
          .toList();
      return medications.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
