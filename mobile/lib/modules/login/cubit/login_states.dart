import 'package:equatable/equatable.dart';

abstract class LoginStates extends Equatable {
  const LoginStates();
  @override
  List<Object?> get props => [];
}

class LoginInitial extends LoginStates {
  const LoginInitial();
}

class LoginPasswordVisibilityChanged extends LoginStates {
  final bool obscurePassword;
  const LoginPasswordVisibilityChanged(this.obscurePassword);
  @override
  List<Object?> get props => [obscurePassword];
}

/// Email ↔ phone input method switched.
class LoginMethodChanged extends LoginStates {
  final bool byPhone;
  const LoginMethodChanged(this.byPhone);
  @override
  List<Object?> get props => [byPhone];
}

class LoginLoading extends LoginStates {
  const LoginLoading();
}

class LoginSuccess extends LoginStates {
  final String role;
  const LoginSuccess(this.role);
  @override
  List<Object?> get props => [role];
}

class LoginError extends LoginStates {
  final String message;
  const LoginError(this.message);
  @override
  List<Object?> get props => [message];
}
