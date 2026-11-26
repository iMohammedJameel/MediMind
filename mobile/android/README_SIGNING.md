# Release signing (MediMind)

Google Play requires a signed `.aab`. Signing keys are NEVER committed.

## 1. Generate an upload keystore (once)

```bash
keytool -genkey -v -keystore medimind-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias medimind-upload
```

Keep a backup of the `.jks` + passwords (lose them = you can never update
the app on Play without resetting the upload key via Play Console support).

## 2. Create `mobile/android/keystore.properties` (not committed)

```properties
storeFile=../medimind-upload.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=medimind-upload
keyPassword=YOUR_KEY_PASSWORD
```

The build script picks it up automatically. Without the file, release
builds fall back to debug signing (fine for local testing, not for Play).

## 3. Build

```bash
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://api.medimind.example/api/v1
```

## Notes

- Application ID: `com.medimind.app` (changed from `com.example.medimind`,
  which Play rejects).
- `USE_EXACT_ALARM` was removed from the manifest (Play policy); the app
  uses `SCHEDULE_EXACT_ALARM` + the in-app opt-in flow (Settings → exact
  alarms) on Android 14+.
- Release builds forbid cleartext traffic — the API base URL must be HTTPS.
