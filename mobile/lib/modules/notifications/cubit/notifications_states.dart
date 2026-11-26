import 'package:equatable/equatable.dart';

import '../../../models/notification_model.dart';

sealed class NotificationsStates extends Equatable {
  const NotificationsStates();
  @override
  List<Object?> get props => [];
}

class NotificationsInitial extends NotificationsStates {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsStates {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsStates {
  final List<NotificationItem> items;
  const NotificationsLoaded(this.items);

  @override
  List<Object?> get props => [items];
}

class NotificationsError extends NotificationsStates {
  final String message;
  const NotificationsError(this.message);

  @override
  List<Object?> get props => [message];
}
