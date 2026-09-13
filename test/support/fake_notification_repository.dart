import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/notifications/model/app_notification.dart';
import 'package:local_markerplace/notifications/repository/notification_repository.dart';

/// The notifications endpoint without a server behind it.
///
/// Hands back the pages it was given, in order, and remembers which were
/// asked for — a drawer that fetches the same page twice is the bug this is
/// here to catch.
class FakeNotificationRepository implements NotificationRepository {
  FakeNotificationRepository({
    this.pages = const [],
    this.failFirst,
    this.failLater,
    this.delay = Duration.zero,
    this.markDelay = Duration.zero,
  });

  final List<NotificationPage> pages;

  /// Fails the first page once, then answers normally — which is what a
  /// retry has to be able to recover from.
  final Failure? failFirst;

  /// Fails every page after the first.
  final Failure? failLater;

  final Duration delay;

  /// Held before marking read returns, so a test can see the drawer while
  /// the server is still being told.
  final Duration markDelay;

  /// The page numbers asked for, in order.
  final List<int> requested = <int>[];

  /// How many times the whole drawer was marked read.
  int markedRead = 0;

  bool _firstHasFailed = false;

  @override
  Future<Either<Failure, NotificationPage>> notifications({
    int page = 0,
    int size = NotificationRepository.defaultPageSize,
  }) async {
    requested.add(page);
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    if (page == 0 && failFirst != null && !_firstHasFailed) {
      _firstHasFailed = true;
      return Left(failFirst!);
    }
    if (page > 0 && failLater != null) return Left(failLater!);

    final index = requested.where((p) => p == page).length - 1;
    final match = pages.where((p) => p.page == page).toList();
    if (match.isEmpty) return Right(const NotificationPage.empty());
    return Right(match[index.clamp(0, match.length - 1)]);
  }

  @override
  Future<Either<Failure, int>> markAllRead() async {
    if (markDelay > Duration.zero) await Future<void>.delayed(markDelay);
    markedRead++;
    _unreadCount = 0;
    return const Right(1);
  }

  @override
  Future<void> refreshBadge() async {
    final result = await notifications(
      size: NotificationRepository.badgeScanSize,
    );
    result.fold((_) {}, (loaded) {
      _unreadCount = loaded.items.where((item) => item.isUnread).length;
      _unreadIsPartial = loaded.hasNext;
    });
  }

  int _unreadCount = 0;
  bool _unreadIsPartial = false;

  @override
  int get unreadCount => _unreadCount;

  @override
  bool get unreadIsPartial => _unreadIsPartial;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  APIClient get apiClient => throw UnimplementedError();
}

/// A page of notifications shaped like the endpoint's own.
NotificationPage samplePage({
  int count = 3,
  int page = 0,
  bool hasNext = false,
  int startId = 1,
  int daysAgo = 0,
}) {
  final now = DateTime.now();

  return NotificationPage.fromJson({
    'items': [
      for (var i = 0; i < count; i++)
        {
          'id': startId + i,
          'kind': i.isEven ? 'VISIT_CONFIRMED' : 'DISPATCH_NO_PARTNER',
          'title': i.isEven
              ? 'Dev Electricals is on the job'
              : 'No one was available',
          'body': 'Your request VIS${startId + i} is confirmed.',
          'entityType': 'VISIT',
          'entityId': startId + i,
          'entityCode': 'VIS${startId + i}',
          'read': false,
          'createdAt': now
              .subtract(Duration(days: daysAgo, minutes: 20 * (i + 1)))
              .toIso8601String(),
        },
    ],
    'page': page,
    'size': 20,
    'totalItems': hasNext ? count * 3 : count,
    'totalPages': hasNext ? 3 : 1,
    'hasNext': hasNext,
  });
}
