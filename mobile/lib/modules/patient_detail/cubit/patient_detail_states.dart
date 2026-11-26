import 'package:equatable/equatable.dart';

import '../../../models/dose_event_model.dart';
import '../../../models/medication_model.dart';

abstract class PatientDetailStates extends Equatable {
  const PatientDetailStates();
  @override
  List<Object?> get props => [];
}

class PatientDetailInitial extends PatientDetailStates {
  const PatientDetailInitial();
}

class PatientDetailLoading extends PatientDetailStates {
  const PatientDetailLoading();
}

class PatientDetailLoaded extends PatientDetailStates {
  final List<DoseEventModel> doses;
  final List<MedicationModel> medications;
  final double weekAdherence;
  const PatientDetailLoaded(
    this.doses, {
    this.medications = const [],
    this.weekAdherence = 0,
  });
  @override
  List<Object?> get props => [doses, medications, weekAdherence];
}

class PatientDetailError extends PatientDetailStates {
  final String message;
  const PatientDetailError(this.message);
  @override
  List<Object?> get props => [message];
}

class PatientDetailActionLoading extends PatientDetailStates {
  final String doseEventId;
  const PatientDetailActionLoading(this.doseEventId);
  @override
  List<Object?> get props => [doseEventId];
}
