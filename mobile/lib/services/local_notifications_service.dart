import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart' show WidgetsFlutterBinding;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../l10n/app_strings.dart';
import '../models/dose_event_model.dart';
import '../services/dose_alarm_watchdog.dart';
import '../services/doses_service.dart';
import '../services/offline_sync_service.dart';
import '../shared/network/local/cache_helper.dart';
import '../shared/network/remote/dio_helper.dart';

/// Local dose-reminder notifications & native alarm clock scheduling.
///
/// Uses Android's native `AlarmManager.setAlarmClock` (via [AndroidScheduleMode.alarmClock])
/// which completely bypasses Android Doze Mode and deep sleep, waking the device
/// from sleep at the exact scheduled second and displaying the full-screen alarm.
///
/// Reminder IDs: a STABLE FNV-1a hash of the dose id — NEVER `String.hashCode`,
/// which the Dart VM re-seeds per isolate/run. Unstable ids meant that after an
/// app restart `cancel()` computed a different id than the one scheduled in the
/// previous run, so a ringing (looping, ongoing) alarm could not be cancelled
/// and duplicate reminders accumulated.
class LocalNotificationsService {
  LocalNotificationsService._();

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Set by main() so a notification tap or alarm trigger can navigate to the alarm screen.
  static void Function(String doseEventId)? onDoseTapped;

  static const _channelId = 'medimind_alarm_clock_v6';
  static String get _channelName => CacheHelper.getLocale() == 'en'
      ? 'Medication Alarm (Full Screen)'
      : 'منبه الأدوية (شاشة كاملة)';
  static String get _channelDesc => CacheHelper.getLocale() == 'en'
      ? 'Full-screen medication dose alerts and alarms'
      : 'تنبيهات ومنبهات مواعيد تناول الأدوية كاملة الشاشة';
  static String get _generalChannelName =>
      CacheHelper.getLocale() == 'en' ? 'General alerts' : 'إشعارات عامة';
  static String get _generalChannelDesc => CacheHelper.getLocale() == 'en'
      ? 'Instant alerts outside scheduled dose times'
      : 'تنبيهات فورية خارج مواعيد الجرعات';

  // ---- Notification action buttons (act WITHOUT opening the app) ----
  static const kActionConfirm = 'medimind_action_confirm';
  static const kActionSnooze = 'medimind_action_snooze';

  /// True after the background isolate finished booting the API stack
  /// (SharedPreferences + secure storage + Dio). The MAIN isolate never
  /// needs this — main() already ran there before any response can arrive.
  static bool _bgApiReady = false;

  /// Stable 31-bit FNV-1a hash — identical across app restarts/isolates.
  static int _stableId(String s) {
    var hash = 0x811c9dc5;
    for (final c in s.codeUnits) {
      hash ^= c;
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  static Future<void> init() async {
    if (_initialized) return;
    // Web target: flutter_local_notifications has no web implementation —
    // every plugin call would throw at runtime. The app runs fully without
    // OS-level reminders on web (dose list + in-app alarm screen still work);
    // production reminders target the Android build.
    if (kIsWeb) return;
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      try {
        final offset = DateTime.now().timeZoneOffset;
        final name = tz.timeZoneDatabase.locations.entries
            .firstWhere((e) => e.value.currentTimeZone.offset == offset.inMilliseconds)
            .key;
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {}
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final actionId = response.actionId;
        // A tap on the notification BODY (actionId empty) navigates to the
        // full-screen alarm as before; an ACTION press is handled in place.
        if (actionId == null || actionId.isEmpty) {
          final doseId = response.payload;
          if (doseId != null && doseId.isNotEmpty) onDoseTapped?.call(doseId);
          return;
        }
        unawaited(handleNotificationAction(response));
      },
      // Fires when an action is pressed while the app is backgrounded —
      // runs in a separate headless isolate (see [_bootApiForBackground]).
      onDidReceiveBackgroundNotificationResponse: alarmBackgroundActionHandler,
    );

    _initialized = true;
  }

  /// True when the OS allows exact alarms (SCHEDULE_EXACT_ALARM granted).
  static Future<bool> exactAlarmsSupported() async {
    if (!_initialized || kIsWeb) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.canScheduleExactNotifications() ?? false;
  }

  /// Opens the system exact-alarms screen for this app (Android 14+ flow —
  /// permission can only be granted there, never via a dialog).
  static Future<void> openExactAlarmSettings() async {
    if (!_initialized || kIsWeb) return;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestExactAlarmsPermission();
  }

  /// Asks for notification permission (Android 13+). Called AFTER the user
  /// has seen the app's value (first schedule load), not at app boot.
  static Future<bool> requestPermissions() async {
    if (!_initialized || kIsWeb) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    return granted ?? true;
  }

  static NotificationDetails _details() {
    final android = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      sound: const RawResourceAndroidNotificationSound('alarm_tone'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      visibility: NotificationVisibility.public,
      // FLAG_INSISTENT (4): Loop alarm tone & vibration continuously until user interacts
      additionalFlags: Int32List.fromList([4]),
      styleInformation: const BigTextStyleInformation(''),
      // ---- Action buttons ON the notification itself ----
      // Industry standard for adherence apps (Medisafe/MyTherapy): users
      // who can't open the app right away still confirm or snooze directly
      // from the notification tray / lock screen. Labels freeze in the
      // active locale at schedule time (same as title/body).
      actions: [
        AndroidNotificationAction(
          kActionConfirm,
          S.get('alarm.actionTaken', CacheHelper.getLocale()),
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          kActionSnooze,
          S.get('alarm.actionSnooze', CacheHelper.getLocale()),
          showsUserInterface: false,
        ),
      ],
    );
    return NotificationDetails(android: android);
  }

  /// Localized notification title — goes through the string catalog (not
  /// hardcoded literals) so EN users get English titles.
  static String _title(bool snooze) => S.get(
        snooze ? 'alarm.notifSnoozeTitle' : 'alarm.notifTitle',
        CacheHelper.getLocale(),
      );

  /// Schedules the reminder for one pending dose using native alarmClock mode.
  static bool _alarmChannelReady = false;

  /// True only on Android when the plugin is booted and `SCHEDULE_EXACT_ALARM`
  /// is currently not granted by the OS (Android 13+/14+ user opt-in).
  static Future<bool> shouldPromptForExactAlarmPermission() async {
    if (kIsWeb || !_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return !(await exactAlarmsSupported());
  }

  /// Requests OS notification permission once per install if not yet asked.
  static Future<void> ensurePermissionsRequested() async {
    if (kIsWeb || !_initialized) return;
    if (!CacheHelper.notifPermissionAsked) {
      await CacheHelper.setNotifPermissionAsked();
      await requestPermissions();
    }
  }

  /// Registers the alarm notification channel upfront with `alarm` audio usage
  /// and custom `alarm_tone` sound so OS settings & notifications use it reliably.
  static Future<void> _ensureAlarmChannel() async {
    if (_alarmChannelReady || kIsWeb) return;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDesc,
          importance: Importance.max,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('alarm_tone'),
          enableVibration: true,
          audioAttributesUsage: AudioAttributesUsage.alarm,
        ),
      );
      _alarmChannelReady = true;
    } catch (_) {
      // iOS / test bindings may have no Android implementation.
    }
  }

  static Future<void> _scheduleAlarmZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    required String payload,
    bool? exactAllowed,
  }) async {
    await _ensureAlarmChannel();
    final canExact = exactAllowed ?? await exactAlarmsSupported();
    final preferredMode = canExact
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details(),
        payload: payload,
        androidScheduleMode: preferredMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } on PlatformException catch (e) {
      // Android 14+ throws `exact_alarms_not_permitted` when SCHEDULE_EXACT_ALARM
      // is revoked/ungranted; degrade cleanly to inexactAllowWhileIdle so doses
      // still get scheduled instead of failing the entire sync.
      if (e.code == 'exact_alarms_not_permitted' &&
          preferredMode != AndroidScheduleMode.inexactAllowWhileIdle) {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          _details(),
          payload: payload,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else {
        rethrow;
      }
    }
  }

  static Future<void> scheduleDoseReminder(
    DoseEventModel dose, {
    bool? exactAllowed,
  }) async {
    if (!_initialized || !(dose.isPending || dose.isLate)) return;
    final when = dose.scheduledFor;
    if (!when.isAfter(DateTime.now())) return;

    await _scheduleAlarmZoned(
      id: _stableId(dose.id),
      title: _title(false),
      body: '${dose.medicationName} — ${dose.timeLabel}',
      when: tz.TZDateTime.from(when, tz.local),
      payload: dose.id,
      exactAllowed: exactAllowed,
    );
  }

  // ---- Reminder registries (persisted) ----

  static Map<String, DateTime> _readSnoozes() {
    try {
      final raw = CacheHelper.getString(CacheHelper.activeSnoozesKey);
      if (raw == null || raw.isEmpty) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(k, DateTime.tryParse(v.toString()) ?? DateTime.now()),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<void> _writeSnoozes(Map<String, DateTime> snoozes) async {
    try {
      await CacheHelper.setString(
        CacheHelper.activeSnoozesKey,
        jsonEncode({
          for (final e in snoozes.entries) e.key: e.value.toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  /// Full reconciliation between the server schedule and OS reminders:
  ///  - schedules reminders for pending/late future doses,
  ///  - KEEPS a pending snooze alive (a refresh must never kill it),
  ///  - cancels reminders for doses confirmed/skipped/missed since the last
  ///    sync, and for doses that vanished entirely (medication deleted or
  ///    deactivated) — previously these kept ringing forever.
  static Future<void> scheduleDoseReminders(List<DoseEventModel> doses) async {
    if (!_initialized) return;
    final now = DateTime.now();
    final snoozes = _readSnoozes();
    final previouslyScheduled =
        CacheHelper.getStringList(CacheHelper.scheduledDoseIdsKey).toSet();
    final keep = <String>{};

    final exactAllowed = await exactAlarmsSupported();
    for (final d in doses) {
      final snoozeUntil = snoozes[d.id];
      final hasActiveSnooze = snoozeUntil != null && snoozeUntil.isAfter(now);
      final dueInFuture = d.scheduledFor.isAfter(now);

      if ((d.isPending || d.isLate) && (dueInFuture || hasActiveSnooze)) {
        if (!hasActiveSnooze) {
          await scheduleDoseReminder(d, exactAllowed: exactAllowed);
        } // else: the snoozed reminder is already scheduled — keep it as is.
        keep.add(d.id);
      } else if (previouslyScheduled.contains(d.id)) {
        // Confirmed / skipped / missed since the last sync → stop reminding.
        await _plugin.cancel(_stableId(d.id));
      }
    }

    // Doses that disappeared from the schedule (medication deleted/deactivated).
    for (final id in previouslyScheduled.difference(keep)) {
      await _plugin.cancel(_stableId(id));
    }

    await CacheHelper.setStringList(CacheHelper.scheduledDoseIdsKey, keep.toList());
    // Prune expired snooze entries.
    final live = <String, DateTime>{
      for (final e in snoozes.entries)
        if (e.value.isAfter(now)) e.key: e.value,
    };
    await _writeSnoozes(live);
    DoseAlarmWatchdog.instance.arm(doses, snoozes: live);
  }

  /// Snooze: cancel the original reminder first (no double alerts), then
  /// re-remind about [dose] after [minutes] — same stable id, no duplicates.
  /// The snooze is recorded so a schedule refresh keeps it alive.
  static Future<void> snooze(DoseEventModel dose, {int minutes = 5}) async {
    if (!_initialized) return;
    final id = _stableId(dose.id);
    await _plugin.cancel(id);
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    await _scheduleAlarmZoned(
      id: id,
      title: _title(true),
      body: '${dose.medicationName} — ${dose.timeLabel}',
      when: when,
      payload: dose.id,
    );
    DoseAlarmWatchdog.instance.armSnooze(dose, when);

    // Keep the dose in the scheduled registry + record the snooze window.
    try {
      final ids =
          CacheHelper.getStringList(CacheHelper.scheduledDoseIdsKey).toSet()
            ..add(dose.id);
      await CacheHelper.setStringList(
          CacheHelper.scheduledDoseIdsKey, ids.toList());
      final snoozes = _readSnoozes()..[dose.id] = when;
      await _writeSnoozes(snoozes);
    } catch (_) {
      // Registry persistence is best-effort; the reminder itself is scheduled.
    }
  }

  /// Cancels the scheduled reminder (+ any snooze) for this dose.
  static Future<void> cancelDose(String doseEventId) async {
    DoseAlarmWatchdog.instance.cancelDose(doseEventId);
    if (!_initialized) return;
    await _plugin.cancel(_stableId(doseEventId));
  }

  /// Cancels everything (user turns reminders off in settings, logout,
  /// account deletion) and clears the registries.
  static Future<void> cancelAll() async {
    DoseAlarmWatchdog.instance.clear();
    if (!_initialized) return;
    await _plugin.cancelAll();
    try {
      await CacheHelper.setStringList(CacheHelper.scheduledDoseIdsKey, []);
      await CacheHelper.setString(CacheHelper.activeSnoozesKey, '{}');
    } catch (_) {}
  }

  /// Shows an immediate notification (foreground announcements from the
  /// NotificationsPoller — e.g. "your patient missed a dose"). Separate id
  /// space from scheduled dose reminders so it never collides with them.
  static Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!_initialized || kIsWeb) return;
    final android = AndroidNotificationDetails(
      'medimind_general_v1',
      _generalChannelName,
      channelDescription: _generalChannelDesc,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body),
    );
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: android),
    );
  }

  /// Payload of the notification that launched the app (cold start), if any.
  static Future<String?> launchPayload() async {
    if (!_initialized) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    final response = details?.notificationResponse;
    final payload = response?.payload;
    return (payload != null && payload.isNotEmpty) ? payload : null;
  }

  // ---- Notification action buttons: confirm / snooze without opening ----

  /// Boots the API stack inside the BACKGROUND isolate (the plugin fires
  /// action presses from a headless engine where main() never ran).
  /// Harmless no-op when already ready. The main isolate skips this —
  /// main() has already initialized everything there.
  static Future<void> _bootApiForBackground() async {
    if (_bgApiReady) return;
    WidgetsFlutterBinding.ensureInitialized();
    await CacheHelper.init();
    DioHelper.init();
    _bgApiReady = true;
  }

  /// Removes a dose from the "scheduled reminders" registry (after the
  /// confirm action) — works from BOTH isolates (same prefs backing store).
  static Future<void> _forgetScheduled(String doseId) async {
    try {
      final ids =
          CacheHelper.getStringList(CacheHelper.scheduledDoseIdsKey).toSet()
            ..remove(doseId);
      await CacheHelper.setStringList(
          CacheHelper.scheduledDoseIdsKey, ids.toList());
      final snoozes = _readSnoozes()..remove(doseId);
      await _writeSnoozes(snoozes);
    } catch (_) {}
  }

  /// Minimal boot for the BACKGROUND isolate (no UI, no callbacks —
  /// the OS-side plugin is already initialized): timezone db + API stack
  /// + marking this isolate's plugin instance usable. Called only from
  /// [alarmBackgroundActionHandler].
  static Future<void> backgroundBoot() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (_) {
      try {
        final offset = DateTime.now().timeZoneOffset;
        final name = tz.timeZoneDatabase.locations.entries
            .firstWhere((e) =>
                e.value.currentTimeZone.offset == offset.inMilliseconds)
            .key;
        tz.setLocalLocation(tz.getLocation(name));
      } catch (_) {}
    }
    await _bootApiForBackground();
    _initialized = true;
  }

  /// Handles an action-button press on a dose reminder notification.
  /// Called from BOTH the foreground callback and the background isolate —
  /// every step is defensive: a failure falls back to "open the app",
  /// which always works.
  static Future<void> handleNotificationAction(
      NotificationResponse response) async {
    if (!_initialized) return;
    final doseId = response.payload;
    if (doseId == null || doseId.isEmpty) return;
    final id = _stableId(doseId);

    if (response.actionId == kActionConfirm) {
      // 1) Silence the ringing reminder immediately — the user acted.
      try {
        await _plugin.cancel(id);
      } catch (_) {}
      // 2) Best-effort API confirm. If offline (non-4xx failure), enqueue into
      //    OfflineSyncService so the action syncs when connectivity returns.
      await OfflineSyncService.instance.updateCachedDoseStatus(doseId, 'TAKEN');
      try {
        await _bootApiForBackground();
        await DosesService().confirmDose(doseId);
      } catch (e) {
        final rejected = e is ApiFailure && e.isDefinitiveRejection;
        if (!rejected) {
          await OfflineSyncService.instance.enqueueAction(
            type: 'CONFIRM_DOSE',
            doseId: doseId,
          );
        }
      }
      await _forgetScheduled(doseId);
      // 3) A quiet confirmation so the user sees it worked.
      try {
        await _plugin.zonedSchedule(
          _stableId('confirmed_$doseId'),
          S.get('alarm.actionConfirmed', CacheHelper.getLocale()),
          '',
          tz.TZDateTime.now(tz.local).add(const Duration(seconds: 2)),
          NotificationDetails(
            android: AndroidNotificationDetails(
              'medimind_general_v1',
              _generalChannelName,
              channelDescription: _generalChannelDesc,
              importance: Importance.low,
              priority: Priority.low,
              autoCancel: true,
            ),
          ),
          payload: doseId,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {}
    } else if (response.actionId == kActionSnooze) {
      try {
        await _bootApiForBackground();
        // Prefer the real dose object (correct med name + reminder title).
        try {
          final doses = await DosesService().todaySchedule();
          final dose = doses.where((d) => d.id == doseId).firstOrNull;
          if (dose != null) {
            await snooze(dose, minutes: 5);
            return;
          }
        } catch (_) {}
        // Fallback (offline / dose not in today's list): re-schedule a
        // generic reminder in 5 minutes so the snooze STILL works.
        await _plugin.cancel(id);
        final when =
            tz.TZDateTime.now(tz.local).add(const Duration(minutes: 5));
        await _scheduleAlarmZoned(
          id: id,
          title: _title(true),
          body: S.get('alarm.actionSnoozed', CacheHelper.getLocale()),
          when: when,
          payload: doseId,
        );
        try {
          final ids =
              CacheHelper.getStringList(CacheHelper.scheduledDoseIdsKey).toSet()
                ..add(doseId);
          await CacheHelper.setStringList(
              CacheHelper.scheduledDoseIdsKey, ids.toList());
          final snoozes = _readSnoozes()..[doseId] = when;
          await _writeSnoozes(snoozes);
        } catch (_) {}
      } catch (_) {}
    }
  }
}

/// Background-isolate entry point for notification ACTION presses (the app
/// was backgrounded/terminated). Must be a top-level function with a
/// fixed name; registered in [FlutterLocalNotificationsPlugin.initialize].
@pragma('vm:entry-point')
Future<void> alarmBackgroundActionHandler(NotificationResponse response) async {
  // A fresh headless isolate has NONE of main()'s state — boot timezones,
  // the plugin instance and the API stack before acting.
  await LocalNotificationsService.backgroundBoot();
  await LocalNotificationsService.handleNotificationAction(response);
}
