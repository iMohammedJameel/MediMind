import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/refill_model.dart';
import '../shared/components/constants.dart';
import '../shared/network/remote/dio_helper.dart';

/// Refill orders + pharmacy directory + medication image uploads.
class RefillService {
  /// POST /medications/refills — request a refill for one medication.
  Future<void> createRefill({
    required String medicationId,
    required String targetPharmacyId,
    required int quantityRequested,
    required String fulfillmentType, // 'PICKUP' | 'DELIVERY'
    Map<String, String>? deliveryAddress,
    String? patientId,
  }) async {
    await DioHelper.post(AppConstants.refillsPath, data: {
      'medicationId': medicationId,
      'targetPharmacyId': targetPharmacyId,
      'quantityRequested': quantityRequested,
      'fulfillmentType': fulfillmentType,
      if (patientId != null) 'patientId': patientId,
      if (deliveryAddress != null && fulfillmentType == 'DELIVERY')
        'deliveryAddress': deliveryAddress,
    });
  }

  /// GET /medications/refills — my refill orders (or a patient's for caregivers).
  Future<List<RefillOrderModel>> listRefills({String? patientId}) async {
    final data = await DioHelper.get(
      AppConstants.refillsPath,
      query: {if (patientId != null) 'patientId': patientId},
    );
    final List list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['refillOrders'] is List) {
      list = data['refillOrders'] as List;
    } else {
      list = const [];
    }
    return list
        .map((j) => RefillOrderModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// PATCH /medications/refills/:id/cancel — cancel a pending refill request.
  Future<void> cancelRefill(String orderId) =>
      DioHelper.patch('${AppConstants.refillsPath}/$orderId/cancel');

  /// GET /profiles/pharmacists — active pharmacy directory.
  Future<List<PharmacyModel>> listPharmacies() async {
    final data = await DioHelper.get(AppConstants.pharmacistsPath);
    final List list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['pharmacies'] is List) {
      list = data['pharmacies'] as List;
    } else {
      list = const [];
    }
    return list
        .map((j) => PharmacyModel.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// POST /uploads/medication-image (multipart) — returns the hosted URL.
  /// Takes raw bytes (not a `dart:io` File path) so it works on Android,
  /// iOS AND web alike.
  Future<String> uploadMedicationImage(Uint8List bytes,
      {String filename = 'medication.jpg'}) async {
    final form = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await DioHelper.dio.post(
      AppConstants.uploadMedicationImagePath,
      data: form,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = res.data;
    if (data is Map && data['data'] is Map) {
      return (data['data']['url'] ?? '').toString();
    }
    return '';
  }
}
