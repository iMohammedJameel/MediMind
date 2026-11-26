import '../models/dose_event_model.dart';
import '../shared/components/constants.dart';
import '../shared/network/remote/dio_helper.dart';

/// Dose schedule API calls.
class DosesService {
  /// Today's dose schedule. Caregivers must pass the target [patientId].
  Future<List<DoseEventModel>> todaySchedule({String? patientId}) async {
    final data = await DioHelper.get(AppConstants.dosesPath, query: {
      if (patientId != null) 'patientId': patientId,
    });
    return _parse(data);
  }

  /// Multi-day schedule (for the weekly/monthly tracker) — the backend's
  /// GET /doses accepts a `date` param, so we fetch each day. Requests run
  /// in small batches (5) instead of one big burst, out of respect for the
  /// backend's rate limiter (30 parallel calls would trip it).
  Future<List<DoseEventModel>> rangeSchedule(
      {required int days, String? patientId}) async {
    final today = DateTime.now();
    final dates = List.generate(
        days, (i) => today.subtract(Duration(days: days - 1 - i)));

    final results = <dynamic>[];
    const batchSize = 5;
    for (var i = 0; i < dates.length; i += batchSize) {
      final chunk = dates.skip(i).take(batchSize).toList();
      final chunkResults = await Future.wait(chunk.map((d) => DioHelper.get(
            AppConstants.dosesPath,
            query: {
              'date':
                  '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
              if (patientId != null) 'patientId': patientId,
            },
          )));
      results.addAll(chunkResults);
    }

    final doses = results.expand(_parse).toList();
    // De-dup across days (the today endpoint may be date-less).
    final seen = <String>{};
    return doses.where((d) => seen.add(d.id)).toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
  }

  List<DoseEventModel> _parse(dynamic data) {
    final list = data is List ? data : (data?['doses'] as List? ?? []);
    return list
        .map((j) => DoseEventModel.fromJson(j as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
  }

  Future<void> confirmDose(String doseEventId) =>
      DioHelper.post('${AppConstants.dosesPath}/$doseEventId/confirm');

  Future<void> skipDose(String doseEventId) =>
      DioHelper.post('${AppConstants.dosesPath}/$doseEventId/skip');

  /// Logs an as-needed (PRN) dose right now — the backend creates the dose
  /// event (status TAKEN, scheduledFor = logging moment) and returns it.
  Future<DoseEventModel> logExtraDose(String medicationId) async {
    final data = await DioHelper.post('${AppConstants.dosesPath}/extra',
        data: {'medicationId': medicationId});
    final map = data is Map ? data : const <String, dynamic>{};
    return DoseEventModel.fromJson(map.cast<String, dynamic>());
  }

  /// Multi-day schedule in a single round-trip using the backend's
  /// `from`/`to` range endpoint (preferred over N per-day calls when
  /// supported — the month tab used to fire 30 separate requests).
  Future<List<DoseEventModel>> rangeScheduleBetween({
    required DateTime from,
    required DateTime to,
    String? patientId,
  }) async {
    String fmt(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final data = await DioHelper.get(AppConstants.dosesPath, query: {
      'from': fmt(from),
      'to': fmt(to),
      if (patientId != null) 'patientId': patientId,
    });
    return _parse(data);
  }
}
