import '../models/notification_model.dart';
import '../shared/components/constants.dart';
import '../shared/network/remote/dio_helper.dart';

/// Notifications inbox API calls.
class NotificationsService {
  Future<List<NotificationItem>> list({int limit = 50}) async {
    final data = await DioHelper.get(
      AppConstants.notificationsPath,
      query: {'limit': limit},
    );
    final list = data is List ? data : (data?['notifications'] as List? ?? []);
    return list
        .map((j) => NotificationItem.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<int> unreadCount() async {
    final data = await DioHelper.get('${AppConstants.notificationsPath}/unread-count');
    return (data is Map ? data['unreadCount'] : 0) as int? ?? 0;
  }

  Future<void> markRead(String id) =>
      DioHelper.patch('${AppConstants.notificationsPath}/$id/read');

  Future<void> markAllRead() =>
      DioHelper.patch('${AppConstants.notificationsPath}/read-all');

  /// Registers this device for server-driven push (FCM token once Firebase
  /// is wired; a local placeholder keeps the contract alive until then).
  Future<void> registerDeviceToken(String token, {String platform = 'ANDROID'}) =>
      DioHelper.post(AppConstants.deviceTokenPath, data: {
        'token': token,
        'platform': platform,
      });
}
