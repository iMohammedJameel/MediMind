import 'dart:async';

import '../shared/components/constants.dart';
import '../shared/network/local/cache_helper.dart';
import '../shared/network/remote/dio_helper.dart';

/// Lightweight product analytics — batched, best-effort, PHI-free.
///
/// Events are queued in memory and flushed:
///  - after 10 events, or
///  - 30 seconds after the first queued event, or
///  - on explicit [flush] (app going to background hook point).
/// Failures are ignored — analytics must never affect the UX.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const int _flushThreshold = 10;
  static const Duration _flushInterval = Duration(seconds: 30);

  final List<Map<String, dynamic>> _queue = [];
  Timer? _timer;
  bool _sending = false;

  /// Event names accepted by the backend whitelist.
  static const appOpen = 'APP_OPEN';
  static const doseConfirmed = 'DOSE_CONFIRMED';
  static const doseSkipped = 'DOSE_SKIPPED';
  static const doseSnoozed = 'DOSE_SNOOZED';
  static const medAdded = 'MED_ADDED';
  static const refillRequested = 'REFILL_REQUESTED';

  void log(String event, {Map<String, dynamic>? properties}) {
    try {
      if (!CacheHelper.isLoggedIn) return; // no anonymous tracking
      _queue.add({
        'event': event,
        if (properties != null && properties.isNotEmpty) 'properties': properties,
        'occurredAt': DateTime.now().toIso8601String(),
      });
      if (_queue.length >= _flushThreshold) {
        unawaited(flush());
      } else {
        _timer ??= Timer(_flushInterval, () => unawaited(flush()));
      }
    } catch (_) {
      // Never throw from analytics.
    }
  }

  Future<void> flush() async {
    if (_sending || _queue.isEmpty) return;
    _sending = true;
    _timer?.cancel();
    _timer = null;

    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    try {
      await DioHelper.post(AppConstants.analyticsEventsPath, data: {
        'events': batch,
      });
    } catch (_) {
      // Drop on failure — analytics is best-effort.
    } finally {
      _sending = false;
    }
  }
}
