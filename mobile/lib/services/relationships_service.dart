import '../models/medication_model.dart';
import '../shared/components/constants.dart';
import '../shared/network/remote/dio_helper.dart';

/// Caregiver↔patient relationship API calls (invites, responses, listing).
class RelationshipsService {
  /// All relationships of the logged-in user (any status) — filter in the UI.
  Future<List<RelationshipModel>> myRelationships() async {
    final data = await DioHelper.get(AppConstants.relationshipsPath);
    final list = data is List ? data : (data?['relationships'] as List? ?? []);
    return list
        .map((j) => RelationshipModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Accepted caregiver↔patient links for the logged-in user.
  Future<List<RelationshipModel>> myPatients() async =>
      (await myRelationships()).where((r) => r.isAccepted).toList();

  /// Patient (or doctor) invites a caregiver by email or phone number.
  Future<void> inviteCaregiver({
    required String caregiverEmail,
    String? relation,
  }) {
    final trimmed = caregiverEmail.trim();
    final isEmail = trimmed.contains('@');
    return DioHelper.post(AppConstants.relationshipsPath, data: {
      if (isEmail) 'caregiverEmail': trimmed else 'caregiverPhone': trimmed,
      if (relation != null && relation.isNotEmpty) 'relation': relation,
    });
  }

  /// Caregiver requests to follow a patient by email or phone number.
  Future<void> requestFollowPatient({
    required String patientIdentifier,
    String? relation,
  }) {
    final trimmed = patientIdentifier.trim();
    final isEmail = trimmed.contains('@');
    return DioHelper.post(AppConstants.relationshipsPath, data: {
      if (isEmail) 'patientEmail': trimmed else 'patientPhone': trimmed,
      if (relation != null && relation.isNotEmpty) 'relation': relation,
    });
  }

  /// Accept or reject a pending invitation (either side may call this).
  Future<void> respond(String relationshipId,
          {required bool accept}) =>
      DioHelper.patch('${AppConstants.relationshipsPath}/$relationshipId/status',
          data: {'status': accept ? 'ACCEPTED' : 'REJECTED'});

  /// Patient permanently removes a caregiver link.
  Future<void> revoke(String relationshipId) =>
      DioHelper.delete('${AppConstants.relationshipsPath}/$relationshipId');
}
