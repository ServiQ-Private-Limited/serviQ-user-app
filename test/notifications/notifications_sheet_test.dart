import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/components/states/empty_state.dart';
import 'package:local_markerplace/components/states/error_state.dart';
import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/notifications/model/app_notification.dart';
import 'package:local_markerplace/notifications/presentation/notifications_sheet.dart';

import '../support/fake_notification_repository.dart';

/// The drawer against the endpoint's pages: what it draws while they are
/// coming, when they arrive, when they run out and when they fail.
Future<void> loadFonts() async {
  for (final path in const [
    'assets/fonts/Mulish-Medium.ttf',
    'assets/fonts/Mulish-Bold.ttf',
    'assets/fonts/Mulish-ExtraBold.ttf',
  ]) {
    final loader = FontLoader('Mulish')
      ..addFont(File(path).readAsBytes().then((b) => ByteData.view(b.buffer)));
    await loader.load();
  }
}

void main() {
  setUpAll(loadFonts);

  Future<void> pumpSheet(
    WidgetTester tester,
    FakeNotificationRepository repository,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Mulish'),
        home: Scaffold(body: NotificationsSheet(repository: repository)),
      ),
    );
  }

  testWidgets('the drawer waits on a skeleton, never a spinner', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      FakeNotificationRepository(
        pages: [samplePage()],
        delay: const Duration(milliseconds: 400),
      ),
    );
    await tester.pump();

    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SkeletonList), findsNothing);
  });

  testWidgets('a page is drawn under the headings the design splits on', (
    tester,
  ) async {
    await pumpSheet(
      tester,
      FakeNotificationRepository(pages: [samplePage(count: 3)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.byType(NotificationRow), findsNWidgets(3));
    // The server's own copy, not something invented for the row.
    expect(find.text('Dev Electricals is on the job'), findsWidgets);
    expect(find.text('No one was available'), findsWidgets);
  });

  testWidgets('scrolling to the end asks for the next page', (tester) async {
    final repository = FakeNotificationRepository(
      pages: [
        // Enough to fill the screen, so nothing loads until it is scrolled.
        samplePage(count: 20, hasNext: true),
        samplePage(count: 6, page: 1, hasNext: false, startId: 100),
      ],
    );
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();
    expect(repository.requested, [0]);

    await tester.drag(
      find.byType(NotificationRow).first,
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();

    expect(repository.requested, [0, 1]);

    // The foot of the longer list says it has ended rather than leaving it
    // ambiguous — reached by scrolling on, as a person would.
    await tester.scrollUntilVisible(
      find.textContaining('That is everything'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('That is everything'), findsOneWidget);
  });

  testWidgets('a page too short to scroll still loads the rest', (
    tester,
  ) async {
    final repository = FakeNotificationRepository(
      pages: [
        samplePage(count: 3, hasNext: true),
        samplePage(count: 3, page: 1, hasNext: false, startId: 100),
      ],
    );
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    // Three rows leave nothing to scroll, and a drawer that can only load
    // more when there is already more would never load the rest.
    expect(repository.requested, [0, 1]);
    expect(find.byType(NotificationRow), findsNWidgets(6));
  });

  testWidgets('marking all read takes the action away', (tester) async {
    final repository = FakeNotificationRepository(
      pages: [samplePage(count: 3)],
    );
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();
    expect(find.text('Mark all read'), findsOneWidget);

    await tester.tap(find.text('Mark all read'));
    await tester.pumpAndSettle();

    expect(repository.markedRead, 1);
    // Nothing left to mark, so the action steps back rather than sitting
    // there doing nothing.
    expect(find.text('Mark all read'), findsNothing);
  });

  testWidgets('a full page of older notifications all render', (tester) async {
    // The shape of a real account: twenty items, every one from previous
    // days, so they land under EARLIER and none under TODAY.
    final repository = FakeNotificationRepository(
      pages: [samplePage(count: 20, hasNext: true, daysAgo: 1)],
    );
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsNothing);
    expect(find.text('EARLIER'), findsOneWidget);

    // A lazy list only builds what is near the viewport, so the twentieth
    // row is proven by scrolling to it rather than by counting widgets.
    await tester.scrollUntilVisible(
      find.textContaining('VIS20'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('VIS20'), findsOneWidget);
  });

  testWidgets('marking read says it is working while it is', (tester) async {
    final repository = FakeNotificationRepository(
      pages: [samplePage(count: 3)],
      markDelay: const Duration(milliseconds: 400),
    );
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark all read'));
    await tester.pump();

    // A slow link would otherwise show a tap that did nothing at all.
    expect(find.text('Marking…'), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);

    // Past the delay: nothing animates while it is in flight, so the clock
    // has to be advanced rather than settled.
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Marking…'), findsNothing);
    expect(find.text('Mark all read'), findsNothing);
    expect(repository.markedRead, 1);
  });

  testWidgets('opening the drawer asks the server every time', (tester) async {
    final repository = FakeNotificationRepository(
      pages: [samplePage(count: 2)],
    );

    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();
    expect(repository.requested, [0]);

    // Closed and opened again: a drawer that showed what it had last time
    // would be showing something that may already be out of date.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.requested, [0, 0]);
  });

  testWidgets('a failure offers a retry that loads the page', (tester) async {
    final repository = FakeNotificationRepository(
      pages: [samplePage(count: 2)],
      failFirst: const Failure(
        errorMessage: 'Service unavailable',
        errorCode: 'INTERNAL_ERROR',
      ),
    );
    await pumpSheet(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text("Couldn't load notifications"), findsOneWidget);
    expect(find.textContaining('quote ref INTERNAL_ERROR'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsNothing);
    expect(find.byType(NotificationRow), findsNWidgets(2));
  });

  testWidgets('an account with no history says so', (tester) async {
    await pumpSheet(
      tester,
      FakeNotificationRepository(pages: [samplePage(count: 0)]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Mark all read'), findsNothing);
  });

  group('the server event names', () {
    test('map onto the marks the drawer has', () {
      expect(
        notificationKindFrom('VISIT_CONFIRMED'),
        NotificationKind.accepted,
      );
      expect(
        notificationKindFrom('DISPATCH_NO_PARTNER'),
        NotificationKind.problem,
      );
      expect(notificationKindFrom('OFFER_RECEIVED'), NotificationKind.offer);
      expect(notificationKindFrom('NEW_MESSAGE'), NotificationKind.message);
      // An event this app has never heard of is still shown, wearing the
      // neutral mark — better than a notification nobody can see.
      expect(notificationKindFrom('SOMETHING_NEW'), NotificationKind.area);
    });

    test('a zoneless stamp is read as UTC, not as local time', () {
      // The endpoint sends UTC without the Z — "2026-09-13T11:53:01.716629"
      // while the device clock says 17:26 in IST. Read as local time it
      // would be five and a half hours in the past, and a notification from
      // three minutes ago would be stamped "5 h".
      final threeMinutesAgo = DateTime.now().toUtc().subtract(
        const Duration(minutes: 3),
      );
      final zoneless = threeMinutesAgo.toIso8601String().replaceAll('Z', '');

      final notification = AppNotification.fromJson({
        'id': 1,
        'kind': 'VISIT_CONFIRMED',
        'title': 'Dev Electricals is on the job',
        'body': 'Your request VIS1 is confirmed.',
        'read': false,
        'createdAt': zoneless,
      });

      expect(notification.age, '3 min');
      // Kept as local time, which is what the drawer groups TODAY on.
      expect(notification.at.isUtc, isFalse);
    });

    test('a stamp that does carry a zone is respected', () {
      final notification = AppNotification.fromJson({
        'id': 2,
        'kind': 'VISIT_CONFIRMED',
        'title': 'Confirmed',
        'body': '',
        'read': true,
        'createdAt': DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 7))
            .toIso8601String(),
      });

      expect(notification.age, '7 min');
    });

    test('the payload parses the way the endpoint sends it', () {
      final page = samplePage(count: 2, hasNext: true);

      expect(page.hasNext, isTrue);
      expect(page.items.first.entityType, 'VISIT');
      expect(page.items.first.entityCode, startsWith('VIS'));
      expect(page.items.first.eventName, 'VISIT_CONFIRMED');
      // "read" is the server's word; the drawer thinks in unread.
      expect(page.items.first.isUnread, isTrue);
    });
  });
}
