import 'package:equatable/equatable.dart';

import '../../../models/medication_model.dart';

sealed class CareCircleStates extends Equatable {
  const CareCircleStates();
  @override
  List<Object?> get props => [];
}

class CareCircleInitial extends CareCircleStates {
  const CareCircleInitial();
}

class CareCircleLoading extends CareCircleStates {
  const CareCircleLoading();
}

class CareCircleLoaded extends CareCircleStates {
  final List<RelationshipModel> accepted;
  final List<RelationshipModel> pending;
  const CareCircleLoaded(this.accepted, this.pending);

  @override
  List<Object?> get props => [accepted, pending];
}

class CareCircleActionLoading extends CareCircleStates {
  final String relationshipId;
  const CareCircleActionLoading(this.relationshipId);

  @override
  List<Object?> get props => [relationshipId];
}

class CareCircleInviteSent extends CareCircleStates {
  const CareCircleInviteSent();
}

class CareCircleError extends CareCircleStates {
  final String message;
  const CareCircleError(this.message);

  @override
  List<Object?> get props => [message];
}
