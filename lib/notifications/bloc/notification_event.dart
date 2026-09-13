part of 'notification_bloc.dart';

sealed class NotificationEvent extends Equatable {
  const NotificationEvent();
}

/// Draw the drawer, from the first page. Also the retry.
final class NotificationsRequested extends NotificationEvent {
  const NotificationsRequested();

  @override
  List<Object> get props => [];
}

/// The seeker reached the bottom of what is loaded.
final class NotificationsNextPageRequested extends NotificationEvent {
  const NotificationsNextPageRequested();

  @override
  List<Object> get props => [];
}

/// "Mark all read" — the drawer's only action.
final class AllNotificationsRead extends NotificationEvent {
  const AllNotificationsRead();

  @override
  List<Object> get props => [];
}
