import 'package:equatable/equatable.dart';

import '../../../models/medication_model.dart';

abstract class ScanStates extends Equatable {
  const ScanStates();
  @override
  List<Object?> get props => [];
}

class ScanInitial extends ScanStates {
  const ScanInitial();
}

class ScanPickingImage extends ScanStates {
  const ScanPickingImage();
}

class ScanProcessing extends ScanStates {
  const ScanProcessing();
}

class ScanSuccess extends ScanStates {
  final ScanResultModel result;
  const ScanSuccess(this.result);
  @override
  List<Object?> get props => [result];
}

class ScanLowConfidence extends ScanStates {
  final ScanResultModel result;
  const ScanLowConfidence(this.result);
  @override
  List<Object?> get props => [result];
}

class ScanBatchSaving extends ScanStates {
  final ScanResultModel result;
  const ScanBatchSaving(this.result);
  @override
  List<Object?> get props => [result];
}

class ScanBatchSaved extends ScanStates {
  final int count;
  final List<InteractionWarningModel> warnings;
  const ScanBatchSaved(this.count, this.warnings);
  @override
  List<Object?> get props => [count, warnings];
}

class ScanError extends ScanStates {
  final String message;
  const ScanError(this.message);
  @override
  List<Object?> get props => [message];
}
