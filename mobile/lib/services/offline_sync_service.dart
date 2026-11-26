import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;

import '../models/dose_event_model.dart';
import '../shared/network/local/cache_helper.dart';
import 'doses_service.dart';

/// Manages offline actions (e.g. confirming/skipping doses when offline)
/// and synchronizes them with the backend once internet connection is restored.
///
/// Drop policy (previously items were deleted SILENTLY on any non-network
/// error — data loss): an item is only dropped when
///  - the server definitively rejected it (4xx — e.g. already confirmed), or
///  - it failed 3 times (network or otherwise).
/// Dropped counts are persisted so the failure is never invisible.
class OfflineSyncService {
  static final OfflineSyncService instance = OfflineSyncService._();
  OfflineSyncService._();

  static const int _maxAttempts = 3;
  // Shared with CacheHelper.clearSession so logout wipes the counter too.
  static const String _droppedCountKey = CacheHelper.offlineDroppedCountKey;

  final DosesService _dosesService = DosesService();
  bool _isSyncing = false;

  /// Live counter of permanently dropped offline actions so the UI can notify
  /// the user instead of failing silently.
  final ValueNotifier<int> droppedNotifier = ValueNotifier<int>(0);

  void refreshDroppedNotifier() {
    try {
      droppedNotifier.value = droppedCount;
    } catch (_) {
      droppedNotifier.value = 0;
    }
  }

  /// Actions still waiting to reach the backend.
  int get pendingCount =>
      CacheHelper.getStringList(CacheHelper.pendingSyncActionsKey).length;

  /// Actions dropped permanently (server-rejected or exhausted retries).
  int get droppedCount {
    try {
      final raw = CacheHelper.getString(_droppedCountKey);
      return raw == null ? 0 : (int.tryParse(raw) ?? 0);
    } catch (_) {
      return 0;
    }
  }

  /// Enqueue an action performed while offline.
  ///
  /// Returns true when the action was safely persisted — false when local
  /// storage is unavailable (callers must then revert any optimistic UI
  /// update, otherwise the patient believes a dose was recorded while
  /// nothing actually happened).
  Future<bool> enqueueAction({
    required String type, // 'CONFIRM_DOSE' | 'SKIP_DOSE'
    required String doseId,
  }) async {
    try {
      final list = CacheHelper.getStringList(CacheHelper.pendingSyncActionsKey);
      // Avoid duplicate queued actions for the same dose
      final filtered = list.where((item) {
        try {
          final decoded = jsonDecode(item) as Map<String, dynamic>;
          return decoded['doseId'] != doseId;
        } catch (_) {
          return true;
        }
      }).toList();

      final action = jsonEncode({
        'type': type,
        'doseId': doseId,
        'timestamp': DateTime.now().toIso8601String(),
        'attempts': 0,
      });
      filtered.add(action);
      await CacheHelper.setStringList(CacheHelper.pendingSyncActionsKey, filtered);
      return true;
    } catch (_) {
      // Storage unavailable — the caller must NOT treat this as queued.
      return false;
    }
  }

  /// Updates the status of a specific dose directly inside the local cache.
  Future<void> updateCachedDoseStatus(String doseId, String status) async {
    try {
      final raw = CacheHelper.getString(CacheHelper.cachedDosesKey);
      if (raw == null) return;
      final strings = (jsonDecode(raw) as List).cast<String>();
      final updatedStrings = <String>[];
      for (final s in strings) {
        final map = jsonDecode(s) as Map<String, dynamic>;
        final id = (map['doseEventId'] ?? map['_id'] ?? '').toString();
        if (id == doseId) {
          map['status'] = status;
        }
        updatedStrings.add(jsonEncode(map));
      }
      await CacheHelper.setString(
        CacheHelper.cachedDosesKey,
        jsonEncode(updatedStrings),
      );
    } catch (_) {}
  }

  /// Retrieves cached doses for today (offline fallback).
  List<DoseEventModel> getCachedDoses() {
    try {
      final raw = CacheHelper.getString(CacheHelper.cachedDosesKey);
      if (raw == null) return [];
      final strings = (jsonDecode(raw) as List).cast<String>();
      final loaded =
          strings.map((s) => DoseEventModel.fromJson(jsonDecode(s))).toList();
      final today = DateTime.now();
      return loaded
          .where((d) =>
              d.scheduledFor.year == today.year &&
              d.scheduledFor.month == today.month &&
              d.scheduledFor.day == today.day)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static bool _isNetworkError(Object e) {
    if (e is ApiFailure) return e.isNetworkError;
    final str = e.toString().toLowerCase();
    return str.contains('socketexception') ||
        str.contains('connection refused') ||
        str.contains('connection closed') ||
        str.contains('network') ||
        str.contains('timeout') ||
        str.contains('timed out');
  }

  /// Server definitively rejected the action (4xx: already confirmed,
  /// deleted, expired, unauthorized…) — retrying will never succeed.
  static bool _isDefinitiveRejection(Object e) =>
      e is ApiFailure && e.isDefinitiveRejection;

  /// Flushes all pending offline actions to the backend.
  /// Returns how many were synced, retried-later and dropped.
  Future<({int synced, int retried, int dropped})> syncPendingActions() async {
    if (_isSyncing) return (synced: 0, retried: 0, dropped: 0);
    final List<String> list;
    try {
      list = CacheHelper.getStringList(CacheHelper.pendingSyncActionsKey);
    } catch (_) {
      // Storage unavailable (e.g. tests before CacheHelper.init) — nothing
      // to sync. This method is fire-and-forget from several places, so it
      // must NEVER throw an unhandled asynchronous error.
      return (synced: 0, retried: 0, dropped: 0);
    }
    if (list.isEmpty) return (synced: 0, retried: 0, dropped: 0);

    _isSyncing = true;
    final remaining = <String>[];
    int synced = 0;
    int dropped = 0;

    try {
      for (final item in list) {
        Map<String, dynamic> decoded;
        try {
          decoded = jsonDecode(item) as Map<String, dynamic>;
          // Malformed entry (missing/corrupted type or doseId) — a hard cast
          // here used to escape the loop and leave _isSyncing stuck true
          // FOREVER, freezing the whole sync pipeline until app restart.
          if (decoded['type'] is! String || decoded['doseId'] is! String) {
            throw const FormatException('malformed action entry');
          }
        } catch (_) {
          dropped++; // nothing recoverable — count and move on
          continue;
        }

        final type = decoded['type'] as String;
        final doseId = decoded['doseId'] as String;
        final attempts = (decoded['attempts'] as num?)?.toInt() ?? 0;

        try {
          if (type == 'CONFIRM_DOSE') {
            await _dosesService.confirmDose(doseId);
          } else if (type == 'SKIP_DOSE') {
            await _dosesService.skipDose(doseId);
          } else {
            dropped++; // unknown action type — cannot ever sync
            continue;
          }
          synced++;
        } catch (e) {
          if (_isNetworkError(e) && attempts + 1 < _maxAttempts) {
            // Still offline-ish: keep for the next connectivity window.
            remaining.add(jsonEncode({
              ...decoded,
              'attempts': attempts + 1,
            }));
          } else if (_isDefinitiveRejection(e)) {
            // Already confirmed / deleted server-side: safe to drop.
            dropped++;
          } else if (attempts + 1 < _maxAttempts) {
            // Unknown failure: retry up to the cap, then drop (never silent).
            remaining.add(jsonEncode({
              ...decoded,
              'attempts': attempts + 1,
            }));
          } else {
            dropped++;
          }
        }
      }

      await CacheHelper.setStringList(
          CacheHelper.pendingSyncActionsKey, remaining);
      if (dropped > 0) {
        final total = droppedCount + dropped;
        await CacheHelper.setString(_droppedCountKey, total.toString());
        droppedNotifier.value = total;
      }
    } finally {
      // ALWAYS release the lock — an unexpected throw anywhere above must
      // never permanently block future syncs.
      _isSyncing = false;
    }
    return (synced: synced, retried: remaining.length, dropped: dropped);
  }

  /// Clears the dropped-actions counter (e.g. after the user acknowledged it).
  Future<void> resetDroppedCount() async {
    try {
      await CacheHelper.setString(_droppedCountKey, '0');
    } catch (_) {}
    droppedNotifier.value = 0;
  }
}
