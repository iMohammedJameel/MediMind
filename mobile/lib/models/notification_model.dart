/// In-app notification item (notifications inbox).
class NotificationItem {
  final String id;
  final String type;
  final String title;
  final String? titleAr;
  final String message;
  final String? messageAr;
  final bool isRead;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.titleAr,
    required this.message,
    this.messageAr,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: (json['_id'] ?? '').toString(),
      type: (json['type'] ?? 'GENERAL').toString(),
      title: (json['title'] ?? '').toString(),
      titleAr: json['titleAr']?.toString(),
      message: (json['message'] ?? '').toString(),
      messageAr: json['messageAr']?.toString(),
      isRead: json['isRead'] == true,
      createdAt:
          DateTime.tryParse('${json['createdAt']}') ?? DateTime.now(),
    );
  }

  /// Arabic-first display values with English fallback.
  String get displayTitle =>
      (titleAr == null || titleAr!.isEmpty) ? title : titleAr!;
  String get displayMessage =>
      (messageAr == null || messageAr!.isEmpty) ? message : messageAr!;

  /// Locale-aware title — English locale prefers the English field (falls
  /// back to Arabic when the server sent none), Arabic prefers Arabic.
  String titleFor(String locale) {
    final ar = titleAr ?? '';
    if (locale == 'en') return title.isNotEmpty ? title : ar;
    return ar.isNotEmpty ? ar : title;
  }

  String messageFor(String locale) {
    final ar = messageAr ?? '';
    if (locale == 'en') return message.isNotEmpty ? message : ar;
    return ar.isNotEmpty ? ar : message;
  }

  bool get isDoseReminder => type.contains('DOSE') || type.contains('REMINDER');
  bool get isMissedDoseAlert => type.contains('MISSED');

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id: id,
        type: type,
        title: title,
        titleAr: titleAr,
        message: message,
        messageAr: messageAr,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}
