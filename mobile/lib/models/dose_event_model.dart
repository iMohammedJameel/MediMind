import '../shared/network/local/cache_helper.dart';
import '../shared/utils/formatters.dart';

/// DoseEvent — one scheduled intake of a medication.
class DoseEventModel {
  final String id;
  final String medicationId;
  final String medicationName;
  final DateTime scheduledFor;
  final String status; // PENDING | TAKEN | MISSED | LATE | SKIPPED

  const DoseEventModel({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.scheduledFor,
    required this.status,
  });

  factory DoseEventModel.fromJson(Map<String, dynamic> json) {
    final med = json['medicationId'];
    var isEn = false;
    try {
      isEn = CacheHelper.getLocale() == 'en';
    } catch (_) {}
    return DoseEventModel(
      id: (json['doseEventId'] ?? json['_id'] ?? '').toString(),
      medicationId: (med is Map ? med['_id'] : med ?? '').toString(),
      medicationName: (med is Map ? med['name'] : null) ??
          json['medicationName'] ??
          (isEn ? 'Medication' : 'دواء'),
      scheduledFor: _parseDate(json['scheduledFor']),
      status: (json['status'] ?? 'PENDING').toString(),
    );
  }

  /// Parses the scheduled time; UTC inputs are converted to device-local so
  /// display and alarm scheduling stay correct regardless of server hosting.
  static DateTime _parseDate(dynamic raw) {
    final parsed = DateTime.tryParse('$raw');
    if (parsed == null) return DateTime.now();
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  bool get isPending => status == 'PENDING';
  bool get isTaken => status == 'TAKEN';
  bool get isMissed => status == 'MISSED';
  bool get isLate => status == 'LATE';
  bool get isSkipped => status == 'SKIPPED';

  /// Locale-aware clock label (e.g. "٨:٣٠ م") honoring the user's
  /// 12/24-hour and Arabic-digits preferences AND the app locale.
  /// Falls back to a plain HH:MM when preferences aren't readable (e.g.
  /// unit tests before CacheHelper.init) — the fallback must never crash.
  String get timeLabel {
    try {
      return AppFormatters.timeOfDay(scheduledFor,
          locale: CacheHelper.getLocale());
    } catch (_) {
      return '${scheduledFor.hour.toString().padLeft(2, '0')}:'
          '${scheduledFor.minute.toString().padLeft(2, '0')}';
    }
  }

  Map<String, dynamic> toJson() => {
        'doseEventId': id,
        'medicationId': medicationId,
        'medicationName': medicationName,
        'scheduledFor': scheduledFor.toIso8601String(),
        'status': status,
      };

  DoseEventModel copyWith({String? status}) => DoseEventModel(
        id: id,
        medicationId: medicationId,
        medicationName: medicationName,
        scheduledFor: scheduledFor,
        status: status ?? this.status,
      );
}

/// Adherence summary computed from a list of dose events.
class AdherenceSummary {
  final int total;
  final int taken;
  final int missed;
  final int late;
  final int pending;
  final int skipped;

  const AdherenceSummary({
    required this.total,
    required this.taken,
    required this.missed,
    required this.late,
    required this.pending,
    required this.skipped,
  });

  factory AdherenceSummary.fromDoses(List<DoseEventModel> doses) {
    return AdherenceSummary(
      total: doses.length,
      taken: doses.where((d) => d.isTaken).length,
      missed: doses.where((d) => d.isMissed).length,
      late: doses.where((d) => d.isLate).length,
      pending: doses.where((d) => d.isPending).length,
      skipped: doses.where((d) => d.isSkipped).length,
    );
  }

  /// taken / total (0 when empty).
  double get percent => total == 0 ? 0 : taken / total;

  /// Adherence over doses DUE SO FAR — future/pending doses are excluded
  /// from the denominator, so 9 AM with an evening dose still coming shows
  /// the morning result instead of a misleading 0%.
  double percentDueSoFar(List<DoseEventModel> doses, [DateTime? now]) {
    final t = now ?? DateTime.now();
    final due = doses.where((d) => !d.scheduledFor.isAfter(t)).toList();
    if (due.isEmpty) return 0;
    return due.where((d) => d.isTaken).length / due.length;
  }

  DoseEventModel? nextPending(List<DoseEventModel> doses) {
    final pending = doses.where((d) => d.isPending).toList()
      ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));
    return pending.isEmpty ? null : pending.first;
  }

  /// Consecutive-day adherence streak (client-side reward system).
  ///
  /// A day counts as "complete" when it had at least one due dose and every
  /// due dose that day was TAKEN (LATE-but-taken counts; MISSED/SKIPPED
  /// break the chain). The streak ends at today (partial: today counts only
  /// if everything due so far is already taken) or at the last complete day.
  static int adherenceStreak(List<DoseEventModel> doses, [DateTime? now]) {
    final t = now ?? DateTime.now();
    if (doses.isEmpty) return 0;

    // Group doses by local calendar day.
    final byDay = <DateTime, List<DoseEventModel>>{};
    for (final d in doses) {
      final key = DateTime(d.scheduledFor.year, d.scheduledFor.month, d.scheduledFor.day);
      byDay.putIfAbsent(key, () => []).add(d);
    }

    bool dayComplete(DateTime day) {
      final list = byDay[day];
      if (list == null || list.isEmpty) return false;
      final isToday = day.year == t.year && day.month == t.month && day.day == t.day;
      // For today only judge doses already due; future ones don't count.
      final due = isToday
          ? list.where((d) => !d.scheduledFor.isAfter(t)).toList()
          : list;
      if (due.isEmpty) return false; // nothing due yet → neutral, break below
      return due.every((d) => d.isTaken);
    }

    var streak = 0;
    var day = DateTime(t.year, t.month, t.day);
    if (dayComplete(day)) {
      streak = 1;
    }
    // Walk backwards from today (or yesterday when today is still neutral).
    day = DateTime(day.year, day.month, day.day - 1);
    while (byDay.containsKey(day) && dayComplete(day)) {
      streak++;
      day = DateTime(day.year, day.month, day.day - 1);
    }
    return streak;
  }

  /// Reward milestone for the current streak (client-side gamification).
  static (int days, String messageKey)? streakMilestone(int streak) {
    if (streak >= 30) return (30, 'streak.milestone30');
    if (streak >= 14) return (14, 'streak.milestone14');
    if (streak >= 7) return (7, 'streak.milestone7');
    if (streak >= 3) return (3, 'streak.milestone3');
    return null;
  }
}
