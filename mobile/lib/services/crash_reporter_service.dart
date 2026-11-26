import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../shared/network/local/cache_helper.dart';
import '../shared/network/remote/dio_helper.dart';

/// Global crash / error reporter.
///
/// Layers (in order):
///  1. Local ring buffer — the last [maxEntries] errors persist in
///     SharedPreferences, surviving restarts (on-device diagnosis).
///  2. Backend analytics (best-effort) — while logged in, APP_ERROR events
///     are batched to POST /analytics/events so the team can see crash
///     volumes from the field.
///  3. Extension point — when the team adds Sentry/Crashlytics, forward
///     from [logError] (single place to wire `Sentry.captureException`).
class CrashReporterService {
  CrashReporterService._();
  static final CrashReporterService instance = CrashReporterService._();

  static const _logKey = 'crash_log';
  static const int maxEntries = 50;

  /// Remote forwarding switch (Settings → "إرسال تقارير الأخطاء").
  bool get remoteEnabled {
    try {
      return CacheHelper.getCrashReportingEnabled();
    } catch (_) {
      return true;
    }
  }

  /// Call once from main() before runApp.
  Future<void> init() async {
    // Nothing heavy today — placeholder for Sentry/Crashlytics init.
  }

  /// Framework errors (FlutterError.onError).
  Future<void> logFlutterError(FlutterErrorDetails details) async {
    await logError(
      details.exceptionAsString(),
      stack: details.stack?.toString(),
      context: details.context?.toString(),
    );
  }

  /// Uncaught zone/platform errors (PlatformDispatcher.onError).
  Future<void> logError(Object error, {String? stack, String? context}) async {
    final entry = jsonEncode({
      'at': DateTime.now().toIso8601String(),
      'error': error.toString(),
      if (stack != null)
        'stack': stack.length > 2000 ? stack.substring(0, 2000) : stack,
      if (context != null) 'context': context,
    });

    try {
      final list = <String>[..._readLog(), entry];
      if (list.length > maxEntries) {
        list.removeRange(0, list.length - maxEntries);
      }
      await CacheHelper.setStringList(_logKey, list);
    } catch (_) {
      // Storage unavailable — never let the reporter itself throw.
    }

    if (kDebugMode) {
      debugPrint('🔥 CrashReporter: $error');
    }

    // Best-effort remote forward while the user opted in AND is logged in.
    if (remoteEnabled) {
      _forwardToBackend(error, context: context);
    }
  }

  /// Recent persisted entries (newest last), for diagnostics UI.
  List<Map<String, dynamic>> recentEntries() {
    return _readLog()
        .map((s) {
          try {
            return jsonDecode(s) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{'raw': s};
          }
        })
        .toList();
  }

  Future<void> clear() async {
    try {
      await CacheHelper.setStringList(_logKey, []);
    } catch (_) {}
  }

  List<String> _readLog() {
    try {
      return CacheHelper.getStringList(_logKey);
    } catch (_) {
      return [];
    }
  }

  Future<void> _forwardToBackend(Object error, {String? context}) async {
    try {
      if (!CacheHelper.isLoggedIn) return;
      await DioHelper.post('/analytics/events', data: {
        'events': [
          {
            'event': 'APP_ERROR',
            'properties': {
              'error': error.toString().substring(0,
                  error.toString().length > 300 ? 300 : error.toString().length),
              if (context != null) 'context': context,
            },
          }
        ],
      });
    } catch (_) {
      // Never propagate reporter failures.
    }
  }
}
