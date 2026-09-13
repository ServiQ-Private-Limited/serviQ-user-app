import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/notifications/model/app_notification.dart';
import 'package:local_markerplace/notifications/repository/notification_repository.dart';

part 'notification_event.dart';
part 'notification_state.dart';

/// The drawer's notifications: a page at a time, and the one thing that can
/// be done to them.
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository notificationRepository;

  NotificationBloc({required this.notificationRepository})
    : super(const NotificationState.initial()) {
    on<NotificationsRequested>(_onNotificationsRequested);
    on<NotificationsNextPageRequested>(_onNextPageRequested);
    on<AllNotificationsRead>(_onAllNotificationsRead);
  }

  /// The first page. Also the retry, which is why it clears the failure.
  Future<void> _onNotificationsRequested(
    NotificationsRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, failure: null, failedAt: null));

    final result = await notificationRepository.notifications(page: 0);
    result.fold(
      (failure) => emit(
        state.copyWith(
          isLoading: false,
          failure: failure,
          failedAt: DateTime.now(),
        ),
      ),
      (loaded) => emit(
        state.copyWith(
          isLoading: false,
          notifications: loaded.items,
          page: loaded.page,
          hasNext: loaded.hasNext,
          totalItems: loaded.totalItems,
          failure: null,
          failedAt: null,
        ),
      ),
    );
  }

  /// The next page, appended.
  ///
  /// A failure here leaves what is already on screen alone — the seeker
  /// scrolled to the bottom of a list that still reads perfectly well, and
  /// replacing it with an error page would take away what they came for.
  Future<void> _onNextPageRequested(
    NotificationsNextPageRequested event,
    Emitter<NotificationState> emit,
  ) async {
    if (!state.hasNext || state.isLoadingMore || state.isLoading) return;
    emit(state.copyWith(isLoadingMore: true));

    final result = await notificationRepository.notifications(
      page: state.page + 1,
    );
    result.fold(
      (failure) => emit(state.copyWith(isLoadingMore: false)),
      (loaded) => emit(
        state.copyWith(
          isLoadingMore: false,
          notifications: [...state.notifications, ...loaded.items],
          page: loaded.page,
          hasNext: loaded.hasNext,
          totalItems: loaded.totalItems,
        ),
      ),
    );
  }

  /// "Mark all read".
  ///
  /// The rows already on screen are marked here rather than being re-fetched:
  /// the server has been told, and a list that flickers back through loading
  /// to show the same lines in a paler shade is a worse answer than one that
  /// simply changes.
  Future<void> _onAllNotificationsRead(
    AllNotificationsRead event,
    Emitter<NotificationState> emit,
  ) async {
    if (!state.hasUnread || state.isMarkingRead) return;
    emit(state.copyWith(isMarkingRead: true, readFailure: null));

    final result = await notificationRepository.markAllRead();

    result.fold(
      (failure) =>
          emit(state.copyWith(isMarkingRead: false, readFailure: failure)),
      (_) => emit(
        state.copyWith(
          isMarkingRead: false,
          notifications: [
            for (final notification in state.notifications)
              notification.copyWith(isUnread: false),
          ],
          readFailure: null,
        ),
      ),
    );
  }
}
