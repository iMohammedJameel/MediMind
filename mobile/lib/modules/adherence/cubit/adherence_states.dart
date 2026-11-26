import 'package:equatable/equatable.dart';

import '../../../models/dose_event_model.dart';
import 'adherence_cubit.dart';

abstract class AdherenceStates extends Equatable {
  const AdherenceStates();
  @override
  List<Object?> get props => [];
}

class AdherenceInitial extends AdherenceStates {
  const AdherenceInitial();
}

class AdherenceLoading extends AdherenceStates {
  const AdherenceLoading();
}

class AdherenceLoaded extends AdherenceStates {
  final List<DoseEventModel> doses;
  final AdherenceSummary summary;
  final AdherenceRange range;

  /// Consecutive-day streak, ALWAYS computed from multi-day history —
  /// computing it from the Today range's single day capped the visible
  /// streak at 1 no matter how long the user's real streak was.
  final int streak;
  const AdherenceLoaded(this.doses, this.summary,
      {required this.range, this.streak = 0});
  @override
  List<Object?> get props => [doses, range, streak];
}

class AdherenceError extends AdherenceStates {
  final String message;
  const AdherenceError(this.message);
  @override
  List<Object?> get props => [message];
}
