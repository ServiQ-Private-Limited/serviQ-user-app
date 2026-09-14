import 'dart:convert';

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
    final raw = jsonDecode(capturedNotificationsPage) as Map<String, dynamic>;
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

/// One page of `/api/v1/user/notifications`, captured off the live endpoint.
///
/// Kept here rather than in a fixtures directory on purpose: a file beside
/// the test is one more thing to remember to commit, and when it goes missing
/// every test in this file fails on a path rather than on the thing it is
/// checking.
const capturedNotificationsPage = r'''
{
  "responseCode": "200 OK",
  "errorCode": null,
  "responseMessage": "Success",
  "responseTime": "2026-09-13T11:15:36.373242395Z",
  "responseData": {
    "items": [
      {
        "id": 577,
        "kind": "DISPATCH_NO_PARTNER",
        "title": "No one was available",
        "body": "We could not find anyone for VISFDSY04M5. Try booking a time instead.",
        "entityType": "VISIT",
        "entityId": 338,
        "entityCode": "VISFDSY04M5",
        "read": false,
        "createdAt": "2026-09-12T09:44:52.091235"
      },
      {
        "id": 574,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Plumbers is on the job",
        "body": "Your request VISLZH85DGV is confirmed.",
        "entityType": "VISIT",
        "entityId": 337,
        "entityCode": "VISLZH85DGV",
        "read": false,
        "createdAt": "2026-09-12T09:44:49.594036"
      },
      {
        "id": 571,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Electricals is on the job",
        "body": "Your request VISTJG4UVQV is confirmed.",
        "entityType": "VISIT",
        "entityId": 336,
        "entityCode": "VISTJG4UVQV",
        "read": false,
        "createdAt": "2026-09-12T09:44:43.179637"
      },
      {
        "id": 528,
        "kind": "DISPATCH_NO_PARTNER",
        "title": "No one was available",
        "body": "We could not find anyone for VISLFZHZO98. Try booking a time instead.",
        "entityType": "VISIT",
        "entityId": 325,
        "entityCode": "VISLFZHZO98",
        "read": false,
        "createdAt": "2026-09-12T09:34:30.547435"
      },
      {
        "id": 525,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Plumbers is on the job",
        "body": "Your request VIS8SSOV8T1 is confirmed.",
        "entityType": "VISIT",
        "entityId": 324,
        "entityCode": "VIS8SSOV8T1",
        "read": false,
        "createdAt": "2026-09-12T09:34:28.06827"
      },
      {
        "id": 522,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Electricals is on the job",
        "body": "Your request VIS9S4046BB is confirmed.",
        "entityType": "VISIT",
        "entityId": 323,
        "entityCode": "VIS9S4046BB",
        "read": false,
        "createdAt": "2026-09-12T09:34:21.878919"
      },
      {
        "id": 510,
        "kind": "DISPATCH_NO_PARTNER",
        "title": "No one was available",
        "body": "We could not find anyone for VISUZ1RH7OO. Try booking a time instead.",
        "entityType": "VISIT",
        "entityId": 321,
        "entityCode": "VISUZ1RH7OO",
        "read": false,
        "createdAt": "2026-09-12T09:26:44.093906"
      },
      {
        "id": 507,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Plumbers is on the job",
        "body": "Your request VIS7US0WTPF is confirmed.",
        "entityType": "VISIT",
        "entityId": 320,
        "entityCode": "VIS7US0WTPF",
        "read": false,
        "createdAt": "2026-09-12T09:26:41.630033"
      },
      {
        "id": 504,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Electricals is on the job",
        "body": "Your request VISJ80OD0O2 is confirmed.",
        "entityType": "VISIT",
        "entityId": 319,
        "entityCode": "VISJ80OD0O2",
        "read": false,
        "createdAt": "2026-09-12T09:26:35.245542"
      },
      {
        "id": 492,
        "kind": "DISPATCH_NO_PARTNER",
        "title": "No one was available",
        "body": "We could not find anyone for VISAMU5N6E2. Try booking a time instead.",
        "entityType": "VISIT",
        "entityId": 317,
        "entityCode": "VISAMU5N6E2",
        "read": false,
        "createdAt": "2026-09-12T08:36:26.512619"
      },
      {
        "id": 489,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Plumbers is on the job",
        "body": "Your request VIS0095YZA1 is confirmed.",
        "entityType": "VISIT",
        "entityId": 316,
        "entityCode": "VIS0095YZA1",
        "read": false,
        "createdAt": "2026-09-12T08:36:24.074516"
      },
      {
        "id": 486,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Electricals is on the job",
        "body": "Your request VIS9KSK7KX9 is confirmed.",
        "entityType": "VISIT",
        "entityId": 315,
        "entityCode": "VIS9KSK7KX9",
        "read": false,
        "createdAt": "2026-09-12T08:36:17.745269"
      },
      {
        "id": 474,
        "kind": "DISPATCH_NO_PARTNER",
        "title": "No one was available",
        "body": "We could not find anyone for VIS9O35LAJJ. Try booking a time instead.",
        "entityType": "VISIT",
        "entityId": 313,
        "entityCode": "VIS9O35LAJJ",
        "read": false,
        "createdAt": "2026-09-12T08:29:38.36271"
      },
      {
        "id": 471,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Plumbers is on the job",
        "body": "Your request VISDZGMT5QM is confirmed.",
        "entityType": "VISIT",
        "entityId": 312,
        "entityCode": "VISDZGMT5QM",
        "read": false,
        "createdAt": "2026-09-12T08:29:35.792855"
      },
      {
        "id": 468,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Electricals is on the job",
        "body": "Your request VISNXQI7ZJ0 is confirmed.",
        "entityType": "VISIT",
        "entityId": 311,
        "entityCode": "VISNXQI7ZJ0",
        "read": false,
        "createdAt": "2026-09-12T08:29:29.086855"
      },
      {
        "id": 456,
        "kind": "DISPATCH_NO_PARTNER",
        "title": "No one was available",
        "body": "We could not find anyone for VISQ5ZSTYWZ. Try booking a time instead.",
        "entityType": "VISIT",
        "entityId": 309,
        "entityCode": "VISQ5ZSTYWZ",
        "read": false,
        "createdAt": "2026-09-09T12:34:04.418141"
      },
      {
        "id": 453,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Plumbers is on the job",
        "body": "Your request VISS2K2X3G5 is confirmed.",
        "entityType": "VISIT",
        "entityId": 308,
        "entityCode": "VISS2K2X3G5",
        "read": false,
        "createdAt": "2026-09-09T12:34:01.888388"
      },
      {
        "id": 450,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Electricals is on the job",
        "body": "Your request VIS4S1ZRAKV is confirmed.",
        "entityType": "VISIT",
        "entityId": 307,
        "entityCode": "VIS4S1ZRAKV",
        "read": false,
        "createdAt": "2026-09-09T12:33:55.363172"
      },
      {
        "id": 438,
        "kind": "DISPATCH_NO_PARTNER",
        "title": "No one was available",
        "body": "We could not find anyone for VISGEUU57CG. Try booking a time instead.",
        "entityType": "VISIT",
        "entityId": 305,
        "entityCode": "VISGEUU57CG",
        "read": false,
        "createdAt": "2026-09-09T12:07:22.973981"
      },
      {
        "id": 435,
        "kind": "VISIT_CONFIRMED",
        "title": "Dev Plumbers is on the job",
        "body": "Your request VIS8FQM0YPR is confirmed.",
        "entityType": "VISIT",
        "entityId": 304,
        "entityCode": "VIS8FQM0YPR",
        "read": false,
        "createdAt": "2026-09-09T12:07:20.487792"
      }
    ],
    "page": 0,
    "size": 20,
    "totalItems": 46,
    "totalPages": 3,
    "hasNext": true
  }
}
''';
