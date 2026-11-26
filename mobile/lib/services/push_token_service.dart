import 'notifications_service.dart';
import 'package:flutter/foundation.dart';

/// Registers this device for server-driven push (FCM).
///
/// WIRING STATUS: the call chain is complete — after every login (and on
/// app start with a restored session) the app asks the token provider and,
/// when a token exists, POSTs it to /notifications/device-token.
///
/// The default provider returns `null` until Firebase Cloud Messaging is
/// configured for the build (firebase_messaging dependency +
/// google-services.json). The moment that lands, `currentToken()` is the
/// single place to return `FirebaseMessaging.instance.getToken()`.
class PushTokenService {
  PushTokenService._();
  static final PushTokenService instance = PushTokenService._();

  /// Whether FCM is enabled for this build.
  /// Build with: flutter build apk --dart-define=FCM_ENABLED=true
  static const bool fcmEnabled =
      bool.fromEnvironment('FCM_ENABLED', defaultValue: false);

  /// The FCM registration token for this device, or null when FCM is not
  /// configured. TODO(fcm): return `FirebaseMessaging.instance.getToken()`
  /// once the firebase_messaging package + google-services.json are added.
  Future<String?> currentToken() async {
    if (!fcmEnabled) {
      debugPrint('PushTokenService: FCM disabled in this build — no token.');
      return null;
    }
    try {
      // return await FirebaseMessaging.instance.getToken();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort device registration right after login/session restore.
  /// Never throws — push is an enhancement, never a blocker.
  Future<void> syncToBackend() async {
    try {
      final token = await currentToken();
      if (token == null || token.isEmpty) return;
      await NotificationsService().registerDeviceToken(token);
    } catch (_) {
      // Silently retry on next login/app-start.
    }
  }
}
