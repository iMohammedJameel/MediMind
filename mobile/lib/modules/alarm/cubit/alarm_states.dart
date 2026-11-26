import 'package:equatable/equatable.dart';

import '../../../models/dose_event_model.dart';

sealed class AlarmStates extends Equatable {
  const AlarmStates();
  @override
  List<Object?> get props => [];
}

class AlarmInitial extends AlarmStates {
  const AlarmInitial();
}

class AlarmLoading extends AlarmStates {
  const AlarmLoading();
}

class AlarmReady extends AlarmStates {
  final DoseEventModel dose;
  const AlarmReady(this.dose);

  @override
  List<Object?> get props => [dose];
}

class AlarmActionLoading extends AlarmStates {
  final AlarmReady previous;
  const AlarmActionLoading(this.previous);

  @override
  List<Object?> get props => [previous];
}

class AlarmDone extends AlarmStates {
  final DoseEventModel dose;
  const AlarmDone(this.dose);

  @override
  List<Object?> get props => [dose];
}

class AlarmError extends AlarmStates {
  final String message;
  /// The dose the failed action referred to — carried so the screen can
  /// re-enable the action buttons and let the user RETRY (previously the
  /// error state rendered an endless spinner with no way out).
  final DoseEventModel dose;
  const AlarmError(this.message, this.dose);

  @override
  List<Object?> get props => [message, dose];
}
