import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../services/auth_service.dart';
import '../../../services/notifications_poller.dart';
import '../../../services/push_token_service.dart';
import 'login_states.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/utils/safe_emit.dart';

class LoginCubit extends Cubit<LoginStates> with SafeEmit<LoginStates> {
  final AuthService _authService;

  LoginCubit([AuthService? authService])
      : _authService = authService ?? AuthService(),
        super(const LoginInitial());

  bool obscurePassword = true;
  bool byPhone = false;

  void togglePasswordVisibility() {
    obscurePassword = !obscurePassword;
    emit(LoginPasswordVisibilityChanged(obscurePassword));
  }

  /// Switch between email and phone login methods.
  void setMethod({required bool byPhone}) {
    this.byPhone = byPhone;
    emit(LoginMethodChanged(byPhone));
  }

  Future<void> login({
    String? email,
    String? phone,
    required String password,
  }) async {
    final usePhone = byPhone;
    if ((usePhone ? phone : email) == null ||
        (usePhone ? phone : email)!.isEmpty ||
        password.isEmpty) {
      emit(const LoginError('err.loginEmpty'));
      return;
    }
    emit(const LoginLoading());
    try {
      final role = await _authService.login(
        email: usePhone ? null : email,
        phone: usePhone ? phone : null,
        password: password,
      );
      // Register this device for server-driven push (no-op until FCM is
      // configured in the build).
      await PushTokenService.instance.syncToBackend();
      NotificationsPoller.instance.start();
      emit(LoginSuccess(role));
    } catch (e) {
      emit(LoginError(apiError(e, 'err.loginFail')));
    }
  }
}
