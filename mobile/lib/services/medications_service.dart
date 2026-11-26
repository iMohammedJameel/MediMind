import '../models/medication_model.dart';
import '../shared/components/constants.dart';
import '../shared/network/remote/dio_helper.dart';

/// Medications & OCR API calls.
class MedicationsService {
  Future<List<MedicationModel>> listMedications({String? patientId}) async {
    final data = await DioHelper.get(
      AppConstants.medicationsPath,
      query: {if (patientId != null) 'patientId': patientId},
    );
    final list = data is List ? data : (data?['medications'] as List? ?? []);
    return list
        .map((j) => MedicationModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Sends a base64 prescription image; returns the OCR extraction.
  Future<ScanResultModel> scanPrescription(String imageBase64) async {
    final data = await DioHelper.post(AppConstants.scanPath, data: {
      'imageBase64': imageBase64,
    });
    return ScanResultModel.fromJson((data ?? const {}) as Map<String, dynamic>);
  }

  /// Creates a medication; returns interaction warnings if any.
  Future<List<InteractionWarningModel>> createMedication(
    Map<String, dynamic> payload,
  ) async {
    final data = await DioHelper.post(AppConstants.medicationsPath, data: payload);
    final warnings = (data?['interactionWarnings'] as List? ?? []);
    return warnings
        .map((w) => InteractionWarningModel.fromJson(w as Map<String, dynamic>))
        .toList();
  }

  /// Partial update (schedule / inventory / isActive) — name is immutable
  /// server-side, per the backend update schema.
  Future<void> updateMedication(String id, Map<String, dynamic> payload) =>
      DioHelper.patch('${AppConstants.medicationsPath}/$id', data: payload);

  Future<void> deleteMedication(String id) =>
      DioHelper.delete('${AppConstants.medicationsPath}/$id');
}
