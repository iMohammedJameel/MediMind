import 'package:equatable/equatable.dart';

import '../../../models/medication_model.dart';

abstract class MedicationsStates extends Equatable {
  const MedicationsStates();
  @override
  List<Object?> get props => [];
}

class MedicationsInitial extends MedicationsStates {
  const MedicationsInitial();
}

class MedicationsLoading extends MedicationsStates {
  const MedicationsLoading();
}

class MedicationsLoaded extends MedicationsStates {
  final List<MedicationModel> medications;
  final bool fromCache;
  const MedicationsLoaded(this.medications, {this.fromCache = false});
  @override
  List<Object?> get props => [medications, fromCache];
}

class MedicationsError extends MedicationsStates {
  final String message;
  const MedicationsError(this.message);
  @override
  List<Object?> get props => [message];
}

class MedicationSaving extends MedicationsStates {
  const MedicationSaving();
}

class MedicationSaved extends MedicationsStates {
  final List<InteractionWarningModel> warnings;
  const MedicationSaved(this.warnings);
  @override
  List<Object?> get props => [warnings];
}

class MedicationSaveError extends MedicationsStates {
  final String message;
  const MedicationSaveError(this.message);
  @override
  List<Object?> get props => [message];
}

class MedicationUpdated extends MedicationsStates {
  const MedicationUpdated();
}

class MedicationDeleted extends MedicationsStates {
  const MedicationDeleted();
}
