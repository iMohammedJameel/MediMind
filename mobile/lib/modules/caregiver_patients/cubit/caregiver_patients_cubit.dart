import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/medication_model.dart';
import '../../../services/relationships_service.dart';
import 'caregiver_patients_states.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/utils/safe_emit.dart';

/// Caregiver's patient list. On action failure the error state is kept (with
/// the loaded lists still on the cubit) — never silently replaced.
class CaregiverPatientsCubit extends Cubit<CaregiverPatientsStates>
    with SafeEmit<CaregiverPatientsStates> {
  final RelationshipsService _relationshipsService;

  CaregiverPatientsCubit([RelationshipsService? service])
      : _relationshipsService = service ?? RelationshipsService(),
        super(const CaregiverPatientsInitial());

  List<RelationshipModel> patients = [];
  List<RelationshipModel> pendingInvites = [];

  Future<void> load() async {
    emit(const CaregiverPatientsLoading());
    try {
      final all = await _relationshipsService.myRelationships();
      patients = all.where((r) => r.isAccepted).toList();
      pendingInvites = all.where((r) => r.isPending).toList();
      emit(CaregiverPatientsLoaded(patients, pendingInvites: pendingInvites));
    } catch (e) {
      emit(CaregiverPatientsError(apiError(e, 'err.patientsLoad')));
    }
  }

  Future<void> respond(String relationshipId, {required bool accept}) async {
    emit(CaregiverPatientsActionLoading(relationshipId));
    try {
      await _relationshipsService.respond(relationshipId, accept: accept);
      await load();
    } catch (e) {
      emit(CaregiverPatientsError(apiError(e, 'err.respondFail')));
    }
  }

  Future<void> requestFollow(String patientIdentifier, String relation) async {
    emit(const CaregiverPatientsActionLoading('invite'));
    try {
      await _relationshipsService.requestFollowPatient(
        patientIdentifier: patientIdentifier,
        relation: relation,
      );
      emit(const CaregiverInviteSent());
      await load();
    } catch (e) {
      emit(CaregiverPatientsError(apiError(e, 'err.inviteFail')));
    }
  }
}
