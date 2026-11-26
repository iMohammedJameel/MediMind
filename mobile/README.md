# MediMind Mobile (Flutter)

Flutter app for **patients** and **caregivers** (family & professional), talking to the
MediMind Node.js backend. Built on the Cubit (BLoC) architecture:

```
lib/
├── main.dart                     ← bootstrap (CacheHelper + DioHelper + BlocObserver)
├── app_router.dart               ← named routes + role-based redirects
├── models/                       ← data models (fromJson)
├── modules/                      ← every screen = independent module
│   └── [screen]/
│       ├── [screen]_screen.dart  ← UI
│       └── cubit/
│           ├── [screen]_cubit.dart
│           └── [screen]_states.dart
├── shared/
│   ├── components/components.dart, constants.dart
│   ├── network/
│   │   ├── local/cache_helper.dart   ← SharedPreferences
│   │   └── remote/dio_helper.dart    ← Dio HTTP
│   ├── styles/colors.dart, styles.dart, theme.dart
│   └── bloc_observer.dart
└── services/                     ← API service classes (auth, doses, medications, relationships)
```

## Screens
- Login / Register (patient or family caregiver, Arabic-first RTL, elderly-friendly sizing)
- Patient: Today (dose cards + adherence ring + next dose + snooze/skip), OCR scan with
  review-before-save, manual medication add (drug-interaction warnings), adherence stats
- Caregiver: patients list (accepted relationships), patient detail with
  confirm-dose-on-behalf
- Settings: profile, role, logout

## Run
```bash
flutter pub get
# Android emulator (backend on the host machine):
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
# Physical device (replace with your machine's LAN IP):
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:8080/api/v1
```

## Test
```bash
flutter pub get    # re-resolves deps after the android_alarm_manager_plus removal
flutter analyze
flutter test      # 19 unit tests (models + cubits with fake services)
```

## QA & hardening pass (Nov 2026)
Full static audit fixes applied on top of this build:
- **Stable reminder IDs** — notification ids now use a deterministic FNV-1a hash of the dose id instead of `String.hashCode` (which the VM re-seeds per run), so cancel/snooze survive app restarts and no duplicate alarms accumulate.
- **Reminder reconciliation** — reminders for confirmed/skipped/missed/deleted medications are now cancelled on every schedule sync (registry-based), and pending snoozes survive refreshes.
- **Offline queue hardening** — malformed entries can no longer freeze the sync pipeline (`_isSyncing` released in `finally`).
- **4xx server rejections are never queued** — confirm/skip revert the optimistic UI and surface the server reason instead of faking success.
- **Alarm screen recovery** — total failures keep the dose retryable; a cold-start tap on a dead dose shows a friendly screen instead of a blank one.
- **Session wipe on logout/delete** — cached meds, offline queue, adherence caches, FCM token and ALL scheduled reminders are cleared (next account on the device starts clean).
- **Session-expiry navigation** — 401 + failed refresh now routes to Login.
- **Streak fix** — the Today tab computes the streak from multi-day history (was capped at 1 day).
- **UX** — logout & caregiver confirm-on-behalf require confirmation; invite/profile-save success feedback; register gained confirm-password + strict Egyptian phone validation + password visibility toggle; the medications list moved above the add-form (now an expandable section); unread-notifications badge; locale-aware notification titles/messages/dates; camera-permission error message; 404 route screen.
- **Removed** the unused `android_alarm_manager_plus` dependency (service/receivers + FOREGROUND_SERVICE permission) — Play-policy hygiene.

## Build
```bash
flutter build apk --release   # verified: builds cleanly
```

> Machine note: `android/gradle.properties` sets `kotlin.incremental=false` and
> `kotlin.compiler.execution.strategy=in-process` to work around a Kotlin daemon
> incremental-cache bug on this machine. On other machines these can be removed.

## Production checklist (before store release)
1. **Signing**: create a real upload keystore and configure
   `android/app/build.gradle` (`signingConfigs.release`) — the current release APK is
   debug-signed and must NOT ship.
2. **API base URL**: set `API_BASE_URL` to the production HTTPS API
   (`--dart-define=API_BASE_URL=https://api.medimind.../api/v1`); Android blocks
   cleartext HTTP by default (correctly so).
3. **App id / name**: change `applicationId` in `android/app/build.gradle` and the app
   label in `AndroidManifest.xml`.
4. **Push notifications**: add `firebase_messaging` + `google-services.json`, then
   register the token via `POST /notifications/device-token`.
5. **Secrets**: JWT is stored in SharedPreferences — acceptable for MVP; consider
   `flutter_secure_storage` for a stricter security posture.


## Known limitations & production notes (updated Aug 2026)

- **API base URL**: dev default is `http://10.0.2.2:8080/api/v1` (emulator →
  host). Release builds forbid cleartext (`src/release/AndroidManifest.xml`) —
  pass your HTTPS URL at build time:
  `flutter build appbundle --dart-define=API_BASE_URL=https://<host>/api/v1`
- **Emulator connectivity gotcha (Windows)**: on some setups the emulator's
  `10.0.2.2` traffic arrives on a virtual Hyper-V/WHPX adapter that Windows
  Firewall treats as a public network → `ERR_CONNECTION_REFUSED` even though
  `localhost:8080` works on the host. Two options:
  1. Allow inbound TCP 8080 for node.exe in Windows Firewall (needs admin), OR
  2. (recommended, no admin needed)
     `adb reverse tcp:8080 tcp:8080` then build/run with
     `--dart-define=API_BASE_URL=http://127.0.0.1:8080/api/v1`.
     Re-run `adb reverse` after each emulator restart.
- **Exact alarms (Android 14+)**: `SCHEDULE_EXACT_ALARM` is opt-in via system
  settings (`USE_EXACT_ALARM` was removed for Play policy compliance).
  Reminders fall back to inexact alarms (a few minutes drift) until the user
  enables the "Exact alarms" tile in Settings.
- **Sessions**: the access token lives in `flutter_secure_storage`; the
  backend's HttpOnly refresh cookie is persisted in the app-private dir and
  used for one automatic refresh+retry on 401.
- **Account deletion**: the UI is wired but the backend endpoint
  (`DELETE /auth/account`) is not implemented yet — the app shows a clear
  unsupported message meanwhile.
- **iOS**: not in scope for this build (Android only).
- **Golden tests**: baselines are platform-dependent; regenerate with
  `flutter test --update-goldens` on your machine.
- **Timezone**: dose times are treated as device-local; UTC timestamps from
  the server are converted to local on parse.
