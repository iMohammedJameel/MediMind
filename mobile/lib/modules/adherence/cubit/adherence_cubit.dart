import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/dose_event_model.dart';
import '../../../services/doses_service.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/utils/safe_emit.dart';
import 'adherence_states.dart';

enum AdherenceRange { today, week, month }

class AdherenceCubit extends Cubit<AdherenceStates>
    with SafeEmit<AdherenceStates> {
  final DosesService _dosesService;

  AdherenceCubit([DosesService? service])
      : _dosesService = service ?? DosesService(),
        super(const AdherenceInitial());

  AdherenceRange range = AdherenceRange.today;

  int get _days =>
      switch (range) { AdherenceRange.today => 1, AdherenceRange.week => 7, _ => 30 };

  Future<void> load({String? patientId}) async {
    emit(const AdherenceLoading());
    // Week/month fetches are 7-30 API calls — cache per day so revisiting
    // the tab is instant and rate-limiter friendly.
    final useCache = range != AdherenceRange.today && patientId == null;
    if (useCache) {
      final cached = _readCacheFor(range);
      if (cached != null) {
        emit(AdherenceLoaded(cached, AdherenceSummary.fromDoses(cached),
            range: range,
            streak: AdherenceSummary.adherenceStreak(cached)));
        return;
      }
    }
    try {
      final doses = range == AdherenceRange.today
          ? await _dosesService.todaySchedule(patientId: patientId)
          : await _dosesService.rangeScheduleBetween(
              from: DateTime.now().subtract(Duration(days: _days - 1)),
              to: DateTime.now(),
              patientId: patientId,
            );
      if (useCache) _writeCacheFor(range, doses);

      // The streak needs MULTI-DAY history. Week/month ranges already carry
      // it; the Today range reuses the same-day week cache (or fetches 7
      // days once — cached for the rest of the day).
      final streakBase = range == AdherenceRange.today
          ? await _streakBase()
          : doses;
      emit(AdherenceLoaded(doses, AdherenceSummary.fromDoses(doses),
          range: range,
          streak: AdherenceSummary.adherenceStreak(streakBase)));
    } catch (e) {
      emit(AdherenceError(apiError(e, 'err.adherenceLoad')));
    }
  }

  /// Multi-day dose history for the streak card (patient view). Best-effort:
  /// when offline with no cache the streak falls back to 0 — never blocks
  /// the screen.
  Future<List<DoseEventModel>> _streakBase() async {
    try {
      final cached = _readCacheFor(AdherenceRange.week);
      if (cached != null) return cached;
      final week = await _dosesService.rangeScheduleBetween(
        from: DateTime.now().subtract(const Duration(days: 6)),
        to: DateTime.now(),
      );
      _writeCacheFor(AdherenceRange.week, week);
      return week;
    } catch (_) {
      return const <DoseEventModel>[];
    }
  }

  String get _todayKey {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  String _cacheKeyFor(AdherenceRange r) =>
      CacheHelper.adherenceCachePrefix + r.name;

  List<DoseEventModel>? _readCacheFor(AdherenceRange r) {
    try {
      final raw = CacheHelper.getString(_cacheKeyFor(r));
      if (raw == null) return null;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      // Only same-day cache (stale tracker data is worse than a spinner).
      // Full yyyy-MM-dd comparison — comparing the day-of-month alone made
      // a 30-day-old cache look "fresh" again mid-month.
      if (decoded['date'] != _todayKey) return null;
      final list = (decoded['doses'] as List)
          .map((j) => DoseEventModel.fromJson(j as Map<String, dynamic>))
          .toList();
      return list;
    } catch (_) {
      return null;
    }
  }

  void _writeCacheFor(AdherenceRange r, List<DoseEventModel> doses) {
    try {
      CacheHelper.setString(
          _cacheKeyFor(r),
          jsonEncode({
            'date': _todayKey,
            'doses': doses.map((d) => d.toJson()).toList(),
          }));
    } catch (_) {}
  }

  Future<void> setRange(AdherenceRange r, {String? patientId}) async {
    range = r;
    await load(patientId: patientId);
  }
}
