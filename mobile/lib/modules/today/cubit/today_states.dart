import 'package:equatable/equatable.dart';

import '../../../models/dose_event_model.dart';

abstract class TodayStates extends Equatable {
  const TodayStates();
  @override
  List<Object?> get props => [];
}

class TodayInitial extends TodayStates {
  const TodayInitial();
}

class TodayLoading extends TodayStates {
  const TodayLoading();
}

class TodayLoaded extends TodayStates {
  final List<DoseEventModel> doses;
  /// True when this data came from the offline cache, not a fresh fetch.
  final bool fromCache;
  const TodayLoaded(this.doses, {this.fromCache = false});
  @override
  List<Object?> get props => [doses, fromCache];
}

class TodayError extends TodayStates {
  final String message;
  const TodayError(this.message);
  @override
  List<Object?> get props => [message];
}

class DoseActionLoading extends TodayStates {
  final String doseEventId;
  const DoseActionLoading(this.doseEventId);
  @override
  List<Object?> get props => [doseEventId];
}

class DoseActionError extends TodayStates {
  final String message;
  const DoseActionError(this.message);
  @override
  List<Object?> get props => [message];
}

/// An as-needed (PRN) quick-log is in flight for this medication id.
class AsNeededLogging extends TodayStates {
  final String medicationId;
  const AsNeededLogging(this.medicationId);
  @override
  List<Object?> get props => [medicationId];
}

/// An as-needed dose was logged successfully (drives the snackbar).
class AsNeededLogged extends TodayStates {
  const AsNeededLogged();
}
