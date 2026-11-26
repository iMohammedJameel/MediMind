import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/auth_service.dart';
import '../../../services/notifications_poller.dart';
import 'register_states.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/utils/safe_emit.dart';

class RegisterCubit extends Cubit<RegisterStates>
    with SafeEmit<RegisterStates> {
  final AuthService _authService;

  RegisterCubit([AuthService? authService])
      : _authService = authService ?? AuthService(),
        super(const RegisterInitial());

  String role = 'PATIENT';
  bool obscurePassword = true;

  /// Emits a DISTINCT state — emitting `const RegisterInitial()` while the
  /// current state is already RegisterInitial is a no-op for Equatable
  /// states, so the UI never rebuilt and the role toggle appeared stuck.
  void setRole(String value) {
    role = value;
    emit(RegisterRoleChanged(value));
  }

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    emit(RegisterPasswordVisibilityChanged(obscurePassword));
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String phone,
  }) async {
    if (firstName.trim().length < 2 ||
        lastName.trim().length < 2 ||
        !email.contains('@') ||
        password.length < 8 ||
        phone.trim().length < 10) {
      emit(const RegisterError('err.registerValidation'));
      return;
    }
    emit(const RegisterLoading());
    try {
      final String registeredRole;
      if (role == 'PATIENT') {
        // No fabricated health data anymore — the profile-setup screen
        // collects the real values right after this call. The backend's
        // session (accessToken) is cached for an automatic login.
        registeredRole = await _authService.registerPatient(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          email: email.trim(),
          password: password,
          countryCode: '+20',
          phone: phone.trim(),
        );
      } else {
        registeredRole = await _authService.registerFamilyCaregiver(
          firstName: firstName.trim(),
          lastName: lastName.trim(),
          email: email.trim(),
          password: password,
          countryCode: '+20',
          phone: phone.trim(),
        );
      }
      NotificationsPoller.instance.start();
      emit(RegisterSuccess(registeredRole));
    } catch (e) {
      emit(RegisterError(apiError(e, 'err.registerFail')));
    }
  }
}
