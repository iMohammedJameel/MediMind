import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, ValueNotifier;

import '../shared/network/local/cache_helper.dart';
import 'local_notifications_service.dart';
import 'notifications_service.dart';

/// Foreground notification freshness for the logged-in user.
///
/// Why this exists: until FCM keys land in the build (PushTokenService is
/// wired and waiting), the ONLY way a caregiver learned "your patient
/// missed a dose" was opening the app. This poller closes the gap while
/// the app is in the foreground:
///  - refreshes the unread badge every 60s,
///  - when new notifications arrive it surfaces them as a real local
///    notification (Android/iOS) — even if the user is on another screen.
///
/// It is intentionally cheap: one lightweight GET per minute, only while
/// logged in, stopped on logout/session-expiry.
class NotificationsPoller {
  NotificationsPoller._();

  static final NotificationsPoller instance = NotificationsPoller._();

  static const _interval = Duration(seconds: 60);

  /// Live unread count — the Today-screen bell badge listens to this.
  final ValueNotifier<int> unread = ValueNotifier<int>(0);

  Timer? _timer;
  bool _polling = false;
  int _lastSeenUnread = 0;

  /// Starts polling when a session exists; safe to call repeatedly.
  void start() {
    stop();
    if (!CacheHelper.isLoggedIn) return;
    _poll(); // immediate first refresh
    _timer = Timer.periodic(_interval, (_) => _poll());
  }

  /// Stops polling (logout, session expiry, account deletion).
  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastSeenUnread = 0;
    unread.value = 0;
  }

  /// Recompute the "seen" baseline — called when the user opens the
  /// notifications inbox, so the poller doesn't re-announce what was read.
  void markSeen() {
    _lastSeenUnread = unread.value;
  }

  Future<void> _poll() async {
    if (_polling || !CacheHelper.isLoggedIn) return;
    _polling = true;
    try {
      final count = await NotificationsService().unreadCount();
      final isNew = count > _lastSeenUnread;
      unread.value = count;
      if (isNew) {
        _lastSeenUnread = count;
        await _announceLatest();
      }
    } catch (_) {
      // Offline / token expired — the next tick retries silently.
    } finally {
      _polling = false;
    }
  }

  /// Shows the newest notification as a local notification (mobile only —
  /// no web implementation; the in-app badge covers web).
  Future<void> _announceLatest() async {
    if (kIsWeb) return;
    try {
      if (!CacheHelper.getNotificationsEnabled()) return;
      final items = await NotificationsService().list(limit: 1);
      if (items.isEmpty) return;
      final latest = items.first;
      final locale = CacheHelper.getLocale();
      await LocalNotificationsService.showNow(
        id: 900001,
        title: latest.titleFor(locale),
        body: latest.messageFor(locale),
      );
    } catch (e) {
      debugPrint('NotificationsPoller announce failed: $e');
    }
  }
}
