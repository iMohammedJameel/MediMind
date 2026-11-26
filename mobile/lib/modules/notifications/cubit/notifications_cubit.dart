import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/notification_model.dart';
import '../../../services/notifications_poller.dart';
import '../../../services/notifications_service.dart';
import 'notifications_states.dart';
import '../../../shared/network/local/cache_helper.dart';
import '../../../shared/utils/safe_emit.dart';

class NotificationsCubit extends Cubit<NotificationsStates>
    with SafeEmit<NotificationsStates> {
  final NotificationsService _notificationsService;

  NotificationsCubit([NotificationsService? service])
      : _notificationsService = service ?? NotificationsService(),
        super(const NotificationsInitial());

  List<NotificationItem> items = [];

  Future<void> load() async {
    emit(const NotificationsLoading());
    try {
      items = await _notificationsService.list();
      NotificationsPoller.instance.unread.value =
          items.where((n) => !n.isRead).length;
      NotificationsPoller.instance.markSeen();
      emit(NotificationsLoaded(items));
    } catch (e) {
      emit(NotificationsError(apiError(e, 'err.notifsLoad')));
    }
  }

  Future<void> markRead(String id) async {
    items = items.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
    NotificationsPoller.instance.unread.value =
        items.where((n) => !n.isRead).length;
    NotificationsPoller.instance.markSeen();
    emit(NotificationsLoaded(items));
    try {
      await _notificationsService.markRead(id);
    } catch (_) {
      // Optimistic update — server sync failure shouldn't disturb the inbox.
    }
  }

  Future<void> markAllRead() async {
    items = items.map((n) => n.copyWith(isRead: true)).toList();
    NotificationsPoller.instance.unread.value = 0;
    NotificationsPoller.instance.markSeen();
    emit(NotificationsLoaded(items));
    try {
      await _notificationsService.markAllRead();
    } catch (_) {}
  }
}
