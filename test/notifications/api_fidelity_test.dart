import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/notifications/model/app_notification.dart';
import 'package:local_markerplace/notifications/presentation/notifications_sheet.dart';

import '../support/fake_notification_repository.dart';
import 'notifications_sheet_test.dart' show loadFonts;

/// The drawer against a response captured off the live endpoint.
///
/// Every other test in this folder feeds the drawer pages this repository
/// built; this one feeds it bytes the server actually sent, so a field the
/// backend renames — or a row the drawer quietly drops — is caught here
/// rather than on somebody's phone.
void main() {
  setUpAll(loadFonts);

  late Map<String, dynamic> payload;
  late List<Map<String, dynamic>> items;

  setUp(() {
    final raw =
        jsonDecode(
              File(
                'test/fixtures/notifications_page0.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    payload = raw['responseData'] as Map<String, dynamic>;
    items = [
      for (final entry in payload['items'] as List)
        Map<String, dynamic>.from(entry as Map),
    ];
  });

  test('every item in the captured page survives parsing intact', () {
    final page = NotificationPage.fromJson(payload);

    expect(page.items.length, items.length);
    expect(page.totalItems, payload['totalItems']);
    expect(page.hasNext, payload['hasNext']);

    for (final (index, sent) in items.indexed) {
      final parsed = page.items[index];
      expect(parsed.id, sent['id'], reason: 'id at $index');
      expect(parsed.title, sent['title'], reason: 'title of ${sent['id']}');
      expect(parsed.body, sent['body'], reason: 'body of ${sent['id']}');
      expect(parsed.eventName, sent['kind'], reason: 'kind of ${sent['id']}');
      expect(parsed.entityCode, sent['entityCode']);
      expect(parsed.isUnread, !(sent['read'] as bool));
    }
  });

  test('the server\'s event names reach the marks the design draws', () {
    final page = NotificationPage.fromJson(payload);
    final marks = {
      for (final n in page.items) n.eventName: n.kind,
    };

    expect(marks['VISIT_CONFIRMED'], NotificationKind.accepted);
    expect(marks['DISPATCH_NO_PARTNER'], NotificationKind.problem);
  });

  testWidgets('the drawer draws every row the page carried, verbatim', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Mulish'),
        home: Scaffold(
          body: NotificationsSheet(
            repository: FakeNotificationRepository(
              pages: [NotificationPage.fromJson({...payload, 'hasNext': false})],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The list is lazy, so rows are collected as they are scrolled past
    // rather than read off one frame.
    final drawn = <int, AppNotification>{};
    void collect() {
      for (final row in tester.widgetList<NotificationRow>(
        find.byType(NotificationRow),
      )) {
        drawn[row.notification.id!] = row.notification;
      }
    }

    collect();
    final list = find.byType(Scrollable).last;
    for (var i = 0; i < 20; i++) {
      await tester.drag(list, const Offset(0, -400));
      await tester.pump();
      collect();
    }

    expect(
      drawn.length,
      items.length,
      reason: 'every notification the server sent should have a row',
    );
    for (final sent in items) {
      final row = drawn[sent['id'] as int];
      expect(row, isNotNull, reason: 'no row for ${sent['id']}');
      expect(row!.title, sent['title']);
      expect(row.body, sent['body']);
    }
  });

  testWidgets('a body long enough to say what to do next is not cut off', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // The longest body the endpoint sends, which is also the one carrying
    // the instruction: it has to survive the row it is drawn in.
    final longest = items.reduce(
      (a, b) => (a['body'] as String).length >= (b['body'] as String).length
          ? a
          : b,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Mulish'),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 390,
              child: NotificationRow(
                notification: AppNotification.fromJson(longest),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final body = tester.widget<Text>(
      find.text(longest['body'] as String),
    );
    final painter = TextPainter(
      text: TextSpan(text: body.data, style: body.style),
      maxLines: body.maxLines,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: tester.getSize(find.text(longest['body'] as String)).width);

    expect(
      painter.didExceedMaxLines,
      isFalse,
      reason: '"${longest['body']}" is cut off in the row',
    );
  });
}
