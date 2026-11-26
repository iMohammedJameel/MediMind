import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../models/medication_model.dart';
import '../../../services/analytics_service.dart';
import '../../../services/doses_service.dart';
import '../../../services/local_notifications_service.dart';
import '../../../services/medications_service.dart';
import '../../../shared/network/local/cache_helper.dart';
import 'scan_states.dart';

class ScanCubit extends Cubit<ScanStates> {
  final MedicationsService _medicationsService;
  final ImagePicker _imagePicker;

  /// Raw image bytes — kept instead of a `dart:io` File so the same code
  /// runs on Android, iOS AND web (where picked images are blob URLs, not
  /// filesystem paths).
  Uint8List? imageBytes;
  ScanResultModel? lastResult;

  ScanCubit([MedicationsService? service, ImagePicker? imagePicker])
      : _medicationsService = service ?? MedicationsService(),
        _imagePicker = imagePicker ?? ImagePicker(),
        super(const ScanInitial());

  Future<void> pickAndScan(ImageSource source) async {
    emit(const ScanPickingImage());
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) {
        emit(const ScanInitial());
        return;
      }
      imageBytes = await picked.readAsBytes();
      emit(const ScanProcessing());

      final result = await _medicationsService
          .scanPrescription(base64Encode(imageBytes!));
      lastResult = result;

      if (result.isConfident) {
        emit(ScanSuccess(result));
      } else {
        emit(ScanLowConfidence(result));
      }
    } on PlatformException catch (e) {
      final denied =
          (e.code).contains('denied') || (e.code).contains('not_available');
      emit(ScanError(denied ? 'err.cameraPermission' : 'err.scanFail'));
    } catch (e) {
      if (kDebugMode) debugPrint('scan error: $e');
      emit(ScanError(apiError(e, 'err.scanFail')));
    }
  }

  /// Batch-saves all reviewed medications extracted from a prescription scan.
  Future<void> saveScannedMedications(List<ScannedMedicationItem> items) async {
    if (items.isEmpty || lastResult == null) return;
    emit(ScanBatchSaving(lastResult!));
    try {
      final now = DateTime.now().toUtc();
      final exp = DateTime.now().add(const Duration(days: 365)).toUtc();
      final allWarnings = <InteractionWarningModel>[];
      var savedCount = 0;

      for (final item in items) {
        if (item.name.trim().isEmpty) continue;
        final warnings = await _medicationsService.createMedication({
          'name': item.name.trim(),
          'formType': item.formType,
          'isChronic': false,
          'schedule': {
            'frequency': item.frequency,
            'dosesPerDay': item.dosesPerDay.clamp(1, 6),
            'firstDoseTime': '08:00',
            'startDate': now.toIso8601String(),
            'endDate': now.add(const Duration(days: 7)).toIso8601String(),
          },
          'inventory': {
            'initialQuantity': 30,
            'currentQuantity': 30,
            'doseAmount': 1.0,
            'refillThreshold': 5,
          },
          'expirationDate': exp.toIso8601String(),
        });
        savedCount++;
        allWarnings.addAll(warnings);
        AnalyticsService.instance.log(AnalyticsService.medAdded,
            properties: {'source': 'ocr_batch', 'formType': item.formType});
      }

      try {
        if (CacheHelper.getNotificationsEnabled()) {
          await LocalNotificationsService.ensurePermissionsRequested();
          final doses = await DosesService().todaySchedule();
          await LocalNotificationsService.scheduleDoseReminders(doses);
        }
      } catch (_) {}

      if (!isClosed) emit(ScanBatchSaved(savedCount, allWarnings));
    } catch (e) {
      if (!isClosed) emit(ScanError(apiError(e, 'err.medSave')));
    }
  }

  void reset() {
    imageBytes = null;
    lastResult = null;
    emit(const ScanInitial());
  }
}
