import '../models/profile_model.dart';
import '../shared/components/constants.dart';
import '../shared/network/local/cache_helper.dart';
import '../shared/network/remote/dio_helper.dart';

/// Profile API calls (role-aware paths).
class ProfileService {
  String get _path {
    final role = CacheHelper.getRole();
    return role == AppConstants.rolePatient
        ? '${AppConstants.profilesPath}/patient/me'
        : '${AppConstants.profilesPath}/caregiver/me';
  }

  Future<ProfileModel> myProfile() async {
    final data = await DioHelper.get(_path);
    return ProfileModel.fromJson((data ?? const {}) as Map<String, dynamic>);
  }

  Future<ProfileModel> updateProfile(Map<String, dynamic> payload) async {
    final data = await DioHelper.put(_path, data: payload);
    return ProfileModel.fromJson((data ?? const {}) as Map<String, dynamic>);
  }

  /// Role-aware update: sends the device timezone so the backend can
  /// schedule doses in the patient's wall-clock time (DST-aware).
  Future<void> syncTimezone(String timezone) async {
    if (CacheHelper.getRole() != AppConstants.rolePatient) return;
    try {
      await DioHelper.put(_path, data: {'timezone': timezone});
    } catch (_) {
      // Non-blocking: default Africa/Cairo applies server-side.
    }
  }

  /// Self-service account deletion (Article 21). The backend requires the
  /// account password for re-authentication.
  Future<void> deleteAccount({required String password}) async {
    await DioHelper.delete(AppConstants.deleteAccountPath, data: {
      'password': password,
    });
  }
}
