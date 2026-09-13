import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/network/api_response.dart';
import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/notifications/model/app_notification.dart';

/// What the notifications drawer reads.
///
/// Both endpoints are the seeker's own, so every call goes out signed — the
/// list answers 401 without a token rather than showing somebody else's.
class NotificationRepository {
  NotificationRepository({required this.apiClient});

  /// The one every bell and the drawer read, so marking things read in the
  /// drawer is reflected by the badge that opened it.
  ///
  /// [APIClient] is a singleton keyed on its first construction, so this
  /// picks up the configured client rather than making a second one.
  static final NotificationRepository shared = NotificationRepository(
    apiClient: APIClient(baseUrl: ''),
  );

  final APIClient apiClient;

  static const _path = '/api/v1/user/notifications';
  static const _readPath = '/api/v1/user/notifications/read';

  /// How long the drawer waits before calling it a failure. The client's
  /// default is two minutes, which for a sheet somebody is looking at is a
  /// hang rather than a wait.
  static const _timeout = Duration(seconds: 10);

  /// A page's worth. Matches the server's own default so the first request
  /// asks for what it would have sent anyway.
  static const defaultPageSize = 20;

  /// How many rows the badge counts across.
  ///
  /// There is no unread-count endpoint, so the only way to know the number is
  /// to look at the notifications themselves — and 50 is as many as the
  /// server will hand over at once. Asking for more is not refused, it is
  /// silently answered with 50, so the number is pinned to what the endpoint
  /// actually does rather than to what we would like it to do.
  static const badgeScanSize = 50;

  /// Announced when the drawer is read, so the bells that badge it are told.
  Stream<void> get changes => _changes.stream;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// How many unread the last fetch saw.
  ///
  /// The backend has no unread-count endpoint, so this is what the drawer
  /// last loaded rather than a true total — see [unreadIsPartial].
  int get unreadCount => _unreadCount;
  int _unreadCount = 0;

  /// True when there were more pages than the count was taken from, so the
  /// badge is a floor rather than the whole story.
  bool get unreadIsPartial => _unreadIsPartial;
  bool _unreadIsPartial = false;

  Future<Either<Failure, NotificationPage>> notifications({
    int page = 0,
    int size = defaultPageSize,
  }) async {
    try {
      final data = await apiClient.get(
        _path,
        queryParameters: {'page': page, 'size': size},
        options: Options(receiveTimeout: _timeout, sendTimeout: _timeout),
      );

      if (data is! Map<String, dynamic>) {
        return const Left(
          Failure(
            errorMessage: 'Unexpected response from the server.',
            errorCode: 'MALFORMED_RESPONSE',
          ),
        );
      }

      final response = ApiResponse.fromJson(data, NotificationPage.fromJson);
      final loaded = response.responseData;
      if (!response.isSuccess || loaded == null) {
        return Left(response.toFailure());
      }

      // Only a page that turned out to be the whole list is allowed to set
      // the badge. The drawer reads in twenties, so counting from whatever
      // it happened to fetch would have made the bell read 20 for a seeker
      // with 46 unread — and worse, would have *dropped* an accurate count
      // to 20 the moment the drawer was opened.
      if (page == 0 && !loaded.hasNext) {
        _unreadCount = loaded.items.where((item) => item.isUnread).length;
        _unreadIsPartial = false;
        _announce();
      }
      return Right(loaded);
    } on DioException catch (e) {
      return Left(failureFromDioException(e));
    } catch (e) {
      return Left(Failure(errorMessage: e.toString()));
    }
  }

  /// Marks everything read. The server answers with how many it changed.
  Future<Either<Failure, int>> markAllRead() async {
    try {
      final data = await apiClient.post(
        _readPath,
        options: Options(receiveTimeout: _timeout, sendTimeout: _timeout),
      );

      if (data is! Map<String, dynamic>) {
        return const Left(
          Failure(
            errorMessage: 'Unexpected response from the server.',
            errorCode: 'MALFORMED_RESPONSE',
          ),
        );
      }

      final response = ApiResponse.fromJson(data, (json) => json);
      if (!response.isSuccess) return Left(response.toFailure());

      _unreadCount = 0;
      _unreadIsPartial = false;
      _announce();
      // responseData is the number marked, which the server sends as a bare
      // integer rather than an object.
      final marked = data['responseData'];
      return Right(marked is int ? marked : 0);
    } on DioException catch (e) {
      return Left(failureFromDioException(e));
    } catch (e) {
      return Left(Failure(errorMessage: e.toString()));
    }
  }

  /// Counts the unread for the bell, without a drawer open.
  ///
  /// Asks for [badgeScanSize] rather than a drawer-sized page so the number
  /// on the bell is the real one: anything short of the whole list can only
  /// undercount it. Past the server's ceiling the count is a floor, which
  /// [unreadIsPartial] says so the badge can show it as one.
  ///
  /// Failures are swallowed: a bell that cannot count is a bell without a
  /// badge, not an error worth putting in front of somebody browsing.
  Future<void> refreshBadge() async {
    final result = await notifications(page: 0, size: badgeScanSize);
    result.fold((_) {}, (loaded) {
      _unreadCount = loaded.items.where((item) => item.isUnread).length;
      _unreadIsPartial = loaded.hasNext;
      _announce();
    });
  }

  void _announce() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
