import 'dart:async';
import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/dose_event_model.dart';
import '../../../models/medication_model.dart';
import '../../../services/analytics_service.dart';
import '../../../services/doses_service.dart';
import '../../../services/medications_service.dart';
import '../../../services/local_notifications_service.dart';
import '../../../services/offline_sync_service.dart';
import '../../../shared/network/local/cache_helper.dart';
import 'today_states.dart';

class TodayCubit extends Cubit<TodayStates> {
  final DosesService _dosesService;
  final MedicationsService _medicationsService;

  TodayCubit(
      [DosesService? dosesService, MedicationsService? medicationsService])
      : _dosesService = dosesService ?? DosesService(),
        _medicationsService = medicationsService ?? MedicationsService(),
        super(const TodayInitial());

  List<DoseEventModel> doses = [];

  /// Active "as-needed" (PRN) medications — unscheduled by nature; the
  /// Today screen shows them as quick-log buttons instead of time slots.
  List<MedicationModel> asNeededMeds = [];

  /// Full medication lookup by id so [DoseCard] can display dosage-form icons
  /// and meal-relation instructions alongside each scheduled dose.
  Map<String, MedicationModel> medsById = const {};

  Future<void> loadSchedule({String? patientId}) async {
    bool hasCache = false;
    if (patientId == null) {
      await _loadCachedMedicationsLookup();
      hasCache = await _loadCachedDoses();
      if (hasCache && doses.isNotEmpty) {
        // Emit cache immediately with 0 delay
        emit(TodayLoaded(doses, fromCache: true));
      }
    }

    if (!hasCache || doses.isEmpty) {
      emit(const TodayLoading());
    }

    try {
      final freshDoses = await _dosesService.todaySchedule(patientId: patientId);
      doses = freshDoses;
      // Keep device reminders in sync with the server schedule (patients only:
      // caregiver views shouldn't fire alarms on the caregiver's phone).
      if (patientId == null) {
        await _syncReminders();
        try {
          await _cacheDoses();
        } catch (_) {
          // Cache unavailable (e.g. tests) — non-fatal.
        }
        // Background sync any pending offline actions now that connection
        // is alive. Fire-and-forget: syncPendingActions never throws.
        unawaited(OfflineSyncService.instance.syncPendingActions());
        // Quick-log list + metadata for scheduled dose cards (own view only).
        await _loadPatientMedications();
      }
      if (isClosed) return;
      emit(TodayLoaded(doses, fromCache: false));
    } catch (e) {
      if (!hasCache || doses.isEmpty) {
        if (!isClosed) emit(TodayError(apiError(e, 'err.dosesLoad')));
      }
    }
  }

  Future<void> _loadPatientMedications() async {
    try {
      final meds = await _medicationsService.listMedications();
      medsById = {for (final m in meds) m.id: m};
      asNeededMeds = meds.where((m) => m.isActive && m.isAsNeeded).toList();
    } catch (_) {
      // The scheduled list still renders; extra metadata simply stays empty.
    }
  }

  Future<void> _loadCachedMedicationsLookup() async {
    try {
      final raw = CacheHelper.getString(CacheHelper.cachedMedicationsKey);
      if (raw == null) return;
      final strings = (jsonDecode(raw) as List).cast<String>();
      final meds = strings
          .map((s) => MedicationModel.fromJson(jsonDecode(s)))
          .toList();
      medsById = {for (final m in meds) m.id: m};
      asNeededMeds = meds.where((m) => m.isActive && m.isAsNeeded).toList();
    } catch (_) {}
  }

  /// Quick-log an as-needed (PRN) dose "now". The backend creates the
  /// dose event with status TAKEN and scheduledFor = the moment of logging,
  /// then it appears in today's timeline (and counts toward adherence).
  Future<void> logAsNeededDose(MedicationModel med) async {
    emit(AsNeededLogging(med.id));
    try {
      final logged = await _dosesService.logExtraDose(med.id);
      doses = [...doses, logged]..sort(
          (a, b) => a.scheduledFor.compareTo(b.scheduledFor));
      unawaited(_decrementCachedInventory(med.id));
      AnalyticsService.instance.log(AnalyticsService.doseConfirmed,
          properties: {'asNeeded': true});
      if (!isClosed) emit(const AsNeededLogged());
      if (!isClosed) emit(TodayLoaded(doses));
    } catch (e) {
      if (!isClosed) emit(DoseActionError(apiError(e, 'err.doseConfirm')));
      if (!isClosed) emit(TodayLoaded(doses));
    }
  }

  /// Schedules reminders ONLY when the user enabled them, and asks for the
  /// notification permission once — after they've seen the app's value,
  /// not at app boot.
  Future<void> _syncReminders() async {
    try {
      if (!CacheHelper.getNotificationsEnabled()) {
        await LocalNotificationsService.cancelAll();
        return;
      }
      if (!CacheHelper.notifPermissionAsked) {
        await LocalNotificationsService.requestPermissions();
        await CacheHelper.setNotifPermissionAsked();
      }
      await LocalNotificationsService.scheduleDoseReminders(doses);
    } catch (_) {
      // Reminder sync must never break the schedule view.
    }
  }

  Future<void> confirmDose(String doseEventId) =>
      _performDoseAction(doseEventId, confirm: true);

  Future<void> skipDose(String doseEventId) =>
      _performDoseAction(doseEventId, confirm: false);

  /// Unified optimistic dose action (confirm / skip) with offline queueing,
  /// 4xx definitive-rejection revert, and local inventory update.
  Future<void> _performDoseAction(
    String doseEventId, {
    required bool confirm,
  }) async {
    emit(DoseActionLoading(doseEventId));

    final targetDose = doses.where((d) => d.id == doseEventId).firstOrNull;
    final previousStatus = targetDose?.status;
    final nextStatus = confirm ? 'TAKEN' : 'SKIPPED';
    final actionType = confirm ? 'CONFIRM_DOSE' : 'SKIP_DOSE';
    final errorKey = confirm ? 'err.doseConfirm' : 'err.doseSkip';

    // 1. Optimistically update local list & cache
    doses = doses
        .map((d) => d.id == doseEventId ? d.copyWith(status: nextStatus) : d)
        .toList();
    await LocalNotificationsService.cancelDose(doseEventId);
    await OfflineSyncService.instance
        .updateCachedDoseStatus(doseEventId, nextStatus);

    // 2. Send to backend; queue offline when unreachable. If BOTH fail
    //    (or the server definitively rejects with 4xx), revert.
    try {
      if (confirm) {
        await _dosesService.confirmDose(doseEventId);
        if (targetDose != null && previousStatus != 'TAKEN') {
          unawaited(_decrementCachedInventory(targetDose.medicationId));
        }
        AnalyticsService.instance.log(AnalyticsService.doseConfirmed);
      } else {
        await _dosesService.skipDose(doseEventId);
        AnalyticsService.instance.log(AnalyticsService.doseSkipped);
      }
      await CacheHelper.invalidateAdherenceCaches();
    } catch (e) {
      if (e is ApiFailure && e.isDefinitiveRejection) {
        doses = doses
            .map((d) => d.id == doseEventId
                ? d.copyWith(status: previousStatus ?? 'PENDING')
                : d)
            .toList();
        await OfflineSyncService.instance.updateCachedDoseStatus(
            doseEventId, previousStatus ?? 'PENDING');
        if (!isClosed) emit(DoseActionError(apiError(e, errorKey)));
      } else {
        final queued = await OfflineSyncService.instance.enqueueAction(
          type: actionType,
          doseId: doseEventId,
        );
        if (!queued) {
          doses = doses
              .map((d) => d.id == doseEventId
                  ? d.copyWith(status: previousStatus ?? 'PENDING')
                  : d)
              .toList();
          await OfflineSyncService.instance.updateCachedDoseStatus(
              doseEventId, previousStatus ?? 'PENDING');
          if (!isClosed) emit(DoseActionError(errorKey));
        }
      }
    }

    if (!isClosed) emit(TodayLoaded(doses));
  }

  Future<void> snooze(DoseEventModel dose, {int minutes = 5}) async {
    // Local-only UX: the server keeps the dose PENDING while we re-remind.
    AnalyticsService.instance.log(AnalyticsService.doseSnoozed);
    try {
      if (CacheHelper.getNotificationsEnabled()) {
        await LocalNotificationsService.snooze(dose, minutes: minutes);
      }
    } catch (_) {}
    if (!isClosed) emit(const TodaySnoozed());
  }

  /// Best-effort local inventory decrement so low-stock warnings stay fresh.
  Future<void> _decrementCachedInventory(String medicationId) async {
    if (medicationId.isEmpty) return;
    try {
      final raw = CacheHelper.getString(CacheHelper.cachedMedicationsKey);
      if (raw == null) return;
      final strings = (jsonDecode(raw) as List).cast<String>();
      final updated = <String>[];
      for (final s in strings) {
        final m = jsonDecode(s) as Map<String, dynamic>;
        if ((m['_id'] ?? m['medicationId'])?.toString() == medicationId &&
            m['inventory'] is Map) {
          final inv = (m['inventory'] as Map).cast<String, dynamic>();
          final cur = (inv['currentQuantity'] as num?)?.toInt();
          final amt = (inv['doseAmount'] as num?)?.toDouble() ?? 1.0;
          if (cur != null) {
            inv['currentQuantity'] = (cur - amt).round().clamp(0, 999999);
            m['inventory'] = inv;
          }
        }
        updated.add(jsonEncode(m));
      }
      await CacheHelper.setString(
          CacheHelper.cachedMedicationsKey, jsonEncode(updated));
    } catch (_) {}
  }

  Future<void> _cacheDoses() async {
    final encoded = doses.map((d) => d.toJson()).toList();
    final strings = encoded.map((m) => jsonEncode(m)).toList();
    await CacheHelper.setString(
        CacheHelper.cachedDosesKey, jsonEncode(strings));
  }

  Future<bool> _loadCachedDoses() async {
    try {
      final raw = CacheHelper.getString(CacheHelper.cachedDosesKey);
      if (raw == null) return false;
      final strings = (jsonDecode(raw) as List).cast<String>();
      final loaded =
          strings.map((s) => DoseEventModel.fromJson(jsonDecode(s))).toList();
      // Ignore stale cache from a previous day.
      final today = DateTime.now();
      final fresh = loaded
          .where((d) =>
              d.scheduledFor.year == today.year &&
              d.scheduledFor.month == today.month &&
              d.scheduledFor.day == today.day)
          .toList();
      doses = fresh;
      return true;
    } catch (_) {
      return false;
    }
  }
}

class TodaySnoozed extends TodayStates {
  const TodaySnoozed();
}
