part of 'notification_bloc.dart';

// Sentinel so copyWith can tell "not passed" apart from an explicit null,
// which is what lets a retry clear the failure left by the attempt before it.
const _unset = Object();

class NotificationState extends Equatable {
  final List<AppNotification> notifications;

  /// The last page loaded, and whether another follows it.
  final int page;
  final bool hasNext;

  /// Everything the server holds, which is more than is loaded.
  final int totalItems;

  /// True until the first page comes back, and again on a retry.
  final bool isLoading;

  /// True while a later page is on its way, which the foot of the list shows
  /// without taking the list away.
  final bool isLoadingMore;

  /// True while the server is being told everything has been read, so the
  /// action can say it is working rather than looking like a dead tap.
  final bool isMarkingRead;

  final Failure? failure;

  /// When the failure happened, for the line under the error state.
  final DateTime? failedAt;

  /// Marking read failed. Kept apart from [failure] because the list is fine
  /// — only the action was refused.
  final Failure? readFailure;

  const NotificationState({
    required this.notifications,
    required this.page,
    required this.hasNext,
    required this.totalItems,
    required this.isLoading,
    required this.isLoadingMore,
    required this.isMarkingRead,
    required this.failure,
    required this.failedAt,
    required this.readFailure,
  });

  const NotificationState.initial({
    this.notifications = const [],
    this.page = 0,
    this.hasNext = false,
    this.totalItems = 0,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.isMarkingRead = false,
    this.failure,
    this.failedAt,
    this.readFailure,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    int? page,
    bool? hasNext,
    int? totalItems,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isMarkingRead,
    Object? failure = _unset,
    Object? failedAt = _unset,
    Object? readFailure = _unset,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      page: page ?? this.page,
      hasNext: hasNext ?? this.hasNext,
      totalItems: totalItems ?? this.totalItems,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isMarkingRead: isMarkingRead ?? this.isMarkingRead,
      failure: failure == _unset ? this.failure : failure as Failure?,
      failedAt: failedAt == _unset ? this.failedAt : failedAt as DateTime?,
      readFailure: readFailure == _unset
          ? this.readFailure
          : readFailure as Failure?,
    );
  }

  /// The two headings the design splits the drawer under.
  List<AppNotification> todayAt(DateTime now) =>
      notifications.where((n) => n.isToday(now)).toList();

  List<AppNotification> earlierAt(DateTime now) =>
      notifications.where((n) => !n.isToday(now)).toList();

  /// Nothing to mark once everything has been read, which is what takes the
  /// action out of the header.
  bool get hasUnread => notifications.any((n) => n.isUnread);

  int get unreadCount => notifications.where((n) => n.isUnread).length;

  /// Loaded and genuinely empty, rather than still arriving or broken.
  bool get isEmpty => !isLoading && failure == null && notifications.isEmpty;

  /// Being offline and the server faulting read differently on the screen.
  bool get isOffline =>
      failure?.errorCode == 'CONNECTION_ERROR' ||
      failure?.errorCode == 'TIMEOUT';

  @override
  List<Object?> get props => [
    notifications,
    page,
    hasNext,
    totalItems,
    isLoading,
    isLoadingMore,
    isMarkingRead,
    failure,
    failedAt,
    readFailure,
  ];
}
