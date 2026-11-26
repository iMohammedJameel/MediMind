import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/dose_event_model.dart';
import '../../../services/alarm_service.dart';
import '../../../services/doses_service.dart';
import '../../../services/local_notifications_service.dart';
import '../../../services/offline_sync_service.dart';
import '../../../shared/network/local/cache_helper.dart';
import 'alarm_states.dart';

/// Logic for the full-screen medication alarm (supports 100% offline operation).
class AlarmCubit extends Cubit<AlarmStates> {
  final DosesService _dosesService;

  AlarmCubit(DoseEventModel dose, {DosesService? dosesService})
      : _dosesService = dosesService ?? DosesService(),
        super(AlarmReady(dose));

  /// Cold-start deep link: resolve dose from network first, or fall back
  /// to local cache when offline.
  static Future<DoseEventModel?> resolveDose(String doseEventId) async {
    try {
      final doses = await DosesService().todaySchedule();
      final match = doses.where((d) => d.id == doseEventId).firstOrNull;
      if (match != null) return match;
    } catch (_) {}

    // Offline fallback from local cache
    try {
      final cached = OfflineSyncService.instance.getCachedDoses();
      final match = cached.where((d) => d.id == doseEventId).firstOrNull;
      if (match != null) return match;
    } catch (_) {}

    // Not found in today's schedule or local cache (handled/deleted) — return
    // null so AlarmScreen shows its friendly localized not-available view.
    return null;
  }

  /// The dose this cubit currently operates on, or null when an action is
  /// already in flight / already finished (double-tap guard — the previous
  /// `(state as AlarmReady)` cast crashed with a StateError on rapid taps).
  DoseEventModel? get _currentDose {
    final s = state;
    if (s is AlarmReady) return s.dose;
    if (s is AlarmActionLoading) return s.previous.dose;
    if (s is AlarmError) return s.dose; // retryable — buttons stay usable
    return null; // AlarmDone / AlarmInitial / AlarmLoading — nothing to act on.
  }

  Future<void> confirmDose() async {
    final dose = _currentDose;
    if (dose == null) return;
    emit(AlarmActionLoading(AlarmReady(dose)));

    // 1. Immediately stop sound and cancel local reminder
    await AlarmService.instance.stopAlarm();
    await LocalNotificationsService.cancelDose(dose.id);
    await OfflineSyncService.instance.updateCachedDoseStatus(dose.id, 'TAKEN');

    // 2. Try sending to server; queue offline ONLY for network problems.
    //    A definitive 4xx rejection (already confirmed by a caregiver, dose
    //    gone…) can never sync — and if the local queue is ALSO unavailable
    //    the dose must NOT be recorded as taken. Both cases revert to a
    //    retryable error state (previously they silently "succeeded").
    try {
      await _dosesService.confirmDose(dose.id);
      await CacheHelper.invalidateAdherenceCaches();
      if (!isClosed) emit(AlarmDone(dose.copyWith(status: 'TAKEN')));
    } catch (e) {
      final rejected = e is ApiFailure && e.isDefinitiveRejection;
      final queued = !rejected &&
          await OfflineSyncService.instance
              .enqueueAction(type: 'CONFIRM_DOSE', doseId: dose.id);
      if (isClosed) return;
      if (queued) {
        emit(AlarmDone(dose.copyWith(status: 'TAKEN')));
      } else {
        // Restore the cached status we optimistically overwrote.
        await OfflineSyncService.instance
            .updateCachedDoseStatus(dose.id, dose.status);
        emit(AlarmError(apiError(e, 'err.doseConfirm'), dose));
      }
    }
  }

  Future<void> skipDose() async {
    final dose = _currentDose;
    if (dose == null) return;
    emit(AlarmActionLoading(AlarmReady(dose)));

    // 1. Immediately stop sound and cancel local reminder
    await AlarmService.instance.stopAlarm();
    await LocalNotificationsService.cancelDose(dose.id);
    await OfflineSyncService.instance.updateCachedDoseStatus(dose.id, 'SKIPPED');

    // 2. Same contract as confirmDose: queue only network failures; a 4xx
    //    rejection or an unavailable queue reverts to a retryable error.
    try {
      await _dosesService.skipDose(dose.id);
      await CacheHelper.invalidateAdherenceCaches();
      if (!isClosed) emit(AlarmDone(dose.copyWith(status: 'SKIPPED')));
    } catch (e) {
      final rejected = e is ApiFailure && e.isDefinitiveRejection;
      final queued = !rejected &&
          await OfflineSyncService.instance
              .enqueueAction(type: 'SKIP_DOSE', doseId: dose.id);
      if (isClosed) return;
      if (queued) {
        emit(AlarmDone(dose.copyWith(status: 'SKIPPED')));
      } else {
        await OfflineSyncService.instance
            .updateCachedDoseStatus(dose.id, dose.status);
        emit(AlarmError(apiError(e, 'err.doseSkip'), dose));
      }
    }
  }

  Future<void> snooze({int minutes = 5}) async {
    final dose = _currentDose;
    if (dose == null) return;
    await AlarmService.instance.stopAlarm();
    // Respect the global reminders toggle — snoozing while reminders are
    // disabled would schedule a reminder the user explicitly turned off.
    try {
      if (CacheHelper.getNotificationsEnabled()) {
        await LocalNotificationsService.snooze(dose, minutes: minutes);
      }
    } catch (_) {}
    if (!isClosed) emit(AlarmDone(dose));
  }
}
