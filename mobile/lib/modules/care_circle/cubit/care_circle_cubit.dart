import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/medication_model.dart';
import '../../../services/relationships_service.dart';
import 'care_circle_states.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/utils/safe_emit.dart';

/// Patient's Care Circle: linked caregivers, pending invites, new invitations.
///
/// Error handling: on action failure we emit ONLY the error state — the
/// previously loaded lists stay available on the cubit so the screen renders
/// them alongside an error banner. (Previously a Loaded state was emitted
/// right after the error, silently swallowing it.)
class CareCircleCubit extends Cubit<CareCircleStates>
    with SafeEmit<CareCircleStates> {
  final RelationshipsService _relationshipsService;

  CareCircleCubit([RelationshipsService? service])
      : _relationshipsService = service ?? RelationshipsService(),
        super(const CareCircleInitial());

  List<RelationshipModel> accepted = [];
  List<RelationshipModel> pending = [];

  Future<void> load() async {
    emit(const CareCircleLoading());
    try {
      final all = await _relationshipsService.myRelationships();
      accepted = all.where((r) => r.isAccepted).toList();
      pending = all.where((r) => r.isPending).toList();
      emit(CareCircleLoaded(accepted, pending));
    } catch (e) {
      emit(CareCircleError(apiError(e, 'err.circleLoad')));
    }
  }

  Future<void> invite(String caregiverEmail, String relation) async {
    emit(const CareCircleActionLoading('invite'));
    try {
      await _relationshipsService.inviteCaregiver(
        caregiverEmail: caregiverEmail,
        relation: relation,
      );
      emit(const CareCircleInviteSent());
      await load();
    } catch (e) {
      emit(CareCircleError(apiError(e, 'err.inviteFail')));
    }
  }

  Future<void> respond(String relationshipId, {required bool accept}) async {
    emit(CareCircleActionLoading(relationshipId));
    try {
      await _relationshipsService.respond(relationshipId, accept: accept);
      await load();
    } catch (e) {
      emit(CareCircleError(apiError(e, 'err.respondFail')));
    }
  }

  Future<void> revoke(String relationshipId) async {
    emit(CareCircleActionLoading(relationshipId));
    try {
      await _relationshipsService.revoke(relationshipId);
      await load();
    } catch (e) {
      emit(CareCircleError(apiError(e, 'err.revokeFail')));
    }
  }
}
