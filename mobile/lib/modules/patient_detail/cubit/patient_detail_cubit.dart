import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/dose_event_model.dart';
import '../../../models/medication_model.dart';
import '../../../services/doses_service.dart';
import '../../../services/medications_service.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/utils/safe_emit.dart';
import 'patient_detail_states.dart';

class PatientDetailCubit extends Cubit<PatientDetailStates>
    with SafeEmit<PatientDetailStates> {
  final DosesService _dosesService;
  final MedicationsService _medicationsService;
  final String patientId;

  PatientDetailCubit(
    this.patientId, [
    DosesService? service,
    MedicationsService? medicationsService,
  ])  : _dosesService = service ?? DosesService(),
        _medicationsService = medicationsService ?? MedicationsService(),
        super(const PatientDetailInitial());

  List<DoseEventModel> doses = [];
  List<MedicationModel> medications = [];
  double weekAdherence = 0;

  Future<void> load() async {
    emit(const PatientDetailLoading());
    try {
      doses = await _dosesService.todaySchedule(patientId: patientId);
      // Best-effort secondary fetches (medications + 7-day adherence).
      try {
        medications =
            await _medicationsService.listMedications(patientId: patientId);
      } catch (_) {}
      try {
        final week = await _dosesService.rangeScheduleBetween(
          from: DateTime.now().subtract(const Duration(days: 6)),
          to: DateTime.now(),
          patientId: patientId,
        );
        weekAdherence = AdherenceSummary.fromDoses(week).percentDueSoFar(week);
      } catch (_) {
        weekAdherence = AdherenceSummary.fromDoses(doses).percentDueSoFar(doses);
      }
      emit(PatientDetailLoaded(
        doses,
        medications: medications,
        weekAdherence: weekAdherence,
      ));
    } catch (e) {
      emit(PatientDetailError(apiError(e, 'err.patientsLoad')));
    }
  }

  /// Caregiver confirms a dose on behalf of the patient.
  Future<void> confirmDose(String doseEventId) async {
    emit(PatientDetailActionLoading(doseEventId));
    try {
      await _dosesService.confirmDose(doseEventId);
      doses = doses
          .map((d) => d.id == doseEventId ? d.copyWith(status: 'TAKEN') : d)
          .toList();
      emit(PatientDetailLoaded(
        doses,
        medications: medications,
        weekAdherence: weekAdherence,
      ));
    } catch (e) {
      // Keep the error visible (snackbar via screen listener) — the loaded
      // list is still on [doses], no follow-up Loaded emit is needed.
      emit(PatientDetailError(apiError(e, 'err.doseConfirm')));
    }
  }
}
