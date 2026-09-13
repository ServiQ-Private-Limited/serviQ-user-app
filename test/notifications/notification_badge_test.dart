import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/notifications/model/app_notification.dart';
import 'package:local_markerplace/notifications/repository/notification_repository.dart';

/// Serves the notifications endpoint out of a list, paging it the way the
/// server does — including the server's own ceiling on `size`, which is what
/// makes a badge that asks for more than 50 a badge that undercounts.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.total, required this.unread});

  final int total;
  final int unread;

  /// What the live endpoint does with a larger `size`: it does not refuse it,
  /// it quietly answers with fifty.
  static const cap = 50;

  /// The (page, size) pairs asked for, in order.
  final List<(int, int)> asked = <(int, int)>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final page = int.parse('${options.queryParameters['page'] ?? 0}');
    final asking = int.parse('${options.queryParameters['size'] ?? 20}');
    final size = asking > cap ? cap : asking;
    asked.add((page, asking));

    final start = page * size;
    final end = (start + size) > total ? total : (start + size);
    final items = [
      for (var i = start; i < end; i++)
        {
          'id': 1000 - i,
          'kind': 'VISIT_CONFIRMED',
          'title': 'Dev Electricals is on the job',
          'body': 'Your request VIS$i is confirmed.',
          'entityType': 'VISIT',
          'entityId': i,
          'entityCode': 'VIS$i',
          'read': i >= unread,
          'createdAt': '2026-09-12T09:44:52.091235',
        },
    ];

    return ResponseBody.fromString(
      jsonEncode({
        'responseCode': '200 OK',
        'errorCode': null,
        'responseMessage': 'Success',
        'responseTime': '2026-09-13T11:15:36.373242395Z',
        'responseData': {
          'items': items,
          'page': page,
          'size': size,
          'totalItems': total,
          'totalPages': (total / size).ceil(),
          'hasNext': end < total,
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  // APIClient is a singleton keyed on its first construction, so the whole
  // file shares one and each test swaps the adapter under it.
  final client = APIClient(baseUrl: 'https://stub.invalid');

  NotificationRepository repositoryServing(_StubAdapter adapter) {
    client.dio.httpClientAdapter = adapter;
    return NotificationRepository(apiClient: client);
  }

  test('the bell counts every unread, not just a drawer page', () async {
    final adapter = _StubAdapter(total: 46, unread: 46);
    final repository = repositoryServing(adapter);

    await repository.refreshBadge();

    expect(repository.unreadCount, 46);
    expect(repository.unreadIsPartial, isFalse);
    expect(adapter.asked.single.$2, NotificationRepository.badgeScanSize);
  });

  test('opening the drawer does not drop the count to a page', () async {
    final adapter = _StubAdapter(total: 46, unread: 46);
    final repository = repositoryServing(adapter);

    await repository.refreshBadge();
    // What the drawer itself asks for on open: twenty of forty-six.
    await repository.notifications(page: 0);

    expect(repository.unreadCount, 46);
  });

  test('a list that fits one page is counted exactly by the drawer', () async {
    final adapter = _StubAdapter(total: 12, unread: 5);
    final repository = repositoryServing(adapter);

    await repository.notifications(page: 0);

    expect(repository.unreadCount, 5);
    expect(repository.unreadIsPartial, isFalse);
  });

  test('past the server ceiling the count says so', () async {
    final adapter = _StubAdapter(total: 130, unread: 130);
    final repository = repositoryServing(adapter);

    await repository.refreshBadge();

    // 50 is all the server will give, so the badge is a floor and knows it.
    expect(repository.unreadCount, 50);
    expect(repository.unreadIsPartial, isTrue);
  });

  test('stamps from the same afternoon read the same age', () {
    final at = DateTime.now().subtract(const Duration(days: 4, hours: 2));
    final half = at.add(const Duration(minutes: 27));

    AppNotification stampedAt(DateTime when) => AppNotification(
      kind: NotificationKind.problem,
      title: 'No one was available',
      body: 'We could not find anyone.',
      at: when,
    );

    expect(stampedAt(at).age, stampedAt(half).age);
    expect(stampedAt(at).age, '4 d');
  });
}
