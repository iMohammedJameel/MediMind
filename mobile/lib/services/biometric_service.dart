import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

import '../l10n/app_strings.dart';
import '../shared/network/local/cache_helper.dart';

/// Fingerprint / face unlock for returning users.
///
/// Why it matters for THIS product: the primary persona is an elderly
/// Egyptian patient for whom typing a password every launch is a real
/// adoption blocker — a missed login means missed medication reminders.
/// With biometrics enabled, coming back to the app is a single touch.
///
/// Scope: biometrics are a UI gate in front of an existing (refresh-cookie)
/// session — the secrets themselves never leave flutter_secure_storage.
/// On platforms without biometric support (web, devices without enrolled
/// fingerprints) the feature hides itself and login works as before.
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  /// Secure-storage key for the user's opt-in.
  static const _enabledKey = 'biometric_login_enabled';

  /// True when this device CAN use biometrics right now (hardware present,
  /// at least one biometric enrolled, not the web target).
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      if (!canCheck || !deviceSupported) return false;
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Whether the current user opted in to biometric unlock.
  Future<bool> isEnabled() async {
    try {
      final v = await CacheHelper.secureRead(_enabledKey);
      return v == 'true';
    } catch (_) {
      return false;
    }
  }

  /// Opt in / out. Only meaningful after a successful password login.
  Future<void> setEnabled(bool enabled) async {
    try {
      await CacheHelper.secureWrite(_enabledKey, enabled ? 'true' : 'false');
    } catch (_) {}
  }

  /// Runs the system biometric prompt. Returns true on success; false when
  /// the user cancelled, failed, or biometrics are unavailable.
  Future<bool> authenticate(String locale) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: S.get('biometric.reason', locale),
        options: const AuthenticationOptions(
          // Allow device PIN/pattern as fallback — never lock the user out.
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Wipe the opt-in (logout / account deletion) so the next account on
  /// this device is never auto-unlocked into someone else's session.
  Future<void> clear() => setEnabled(false);
}
