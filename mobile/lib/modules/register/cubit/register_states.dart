import 'package:equatable/equatable.dart';

abstract class RegisterStates extends Equatable {
  const RegisterStates();
  @override
  List<Object?> get props => [];
}

class RegisterInitial extends RegisterStates {
  const RegisterInitial();
}

class RegisterLoading extends RegisterStates {
  const RegisterLoading();
}

class RegisterSuccess extends RegisterStates {
  /// Role of the freshly created account (session already cached by the
  /// cubit — patients skip a second login and go to profile setup).
  final String role;
  const RegisterSuccess(this.role);
  @override
  List<Object?> get props => [role];
}

class RegisterRoleChanged extends RegisterStates {
  final String role;
  const RegisterRoleChanged(this.role);
  @override
  List<Object?> get props => [role];
}

class RegisterPasswordVisibilityChanged extends RegisterStates {
  final bool obscure;
  const RegisterPasswordVisibilityChanged(this.obscure);
  @override
  List<Object?> get props => [obscure];
}

class RegisterError extends RegisterStates {
  final String message;
  const RegisterError(this.message);
  @override
  List<Object?> get props => [message];
}
