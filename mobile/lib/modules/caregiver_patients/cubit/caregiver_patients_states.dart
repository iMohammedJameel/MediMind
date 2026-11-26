import 'package:equatable/equatable.dart';

import '../../../models/medication_model.dart';

abstract class CaregiverPatientsStates extends Equatable {
  const CaregiverPatientsStates();
  @override
  List<Object?> get props => [];
}

class CaregiverPatientsInitial extends CaregiverPatientsStates {
  const CaregiverPatientsInitial();
}

class CaregiverPatientsLoading extends CaregiverPatientsStates {
  const CaregiverPatientsLoading();
}

class CaregiverPatientsLoaded extends CaregiverPatientsStates {
  final List<RelationshipModel> patients;
  final List<RelationshipModel> pendingInvites;
  const CaregiverPatientsLoaded(this.patients, {this.pendingInvites = const []});
  @override
  List<Object?> get props => [patients, pendingInvites];
}

class CaregiverPatientsActionLoading extends CaregiverPatientsStates {
  final String relationshipId;
  const CaregiverPatientsActionLoading(this.relationshipId);
  @override
  List<Object?> get props => [relationshipId];
}

class CaregiverInviteSent extends CaregiverPatientsStates {
  const CaregiverInviteSent();
}

class CaregiverPatientsError extends CaregiverPatientsStates {
  final String message;
  const CaregiverPatientsError(this.message);
  @override
  List<Object?> get props => [message];
}
