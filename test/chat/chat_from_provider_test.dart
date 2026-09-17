import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/chat/model/chat_message.dart';
import 'package:local_markerplace/chat/model/chat_thread.dart';
import 'package:local_markerplace/chat/presentation/chats_page.dart';
import 'package:local_markerplace/chat/repository/chat_repository.dart';

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

/// Chat, reached from a provider's page.
///
/// The button has to land on a conversation either way: the one they already
/// have, or a new one. It used to be a "coming soon" notice, and the
/// repository threw for a provider with no thread.
void main() {
  setUpAll(loadFonts);

  ChatRepository withThread() => ChatRepository(
    threads: [
      ChatThread(
        providerName: 'Dev Electricals',
        isVerified: true,
        unreadCount: 2,
        messages: [
          ChatMessage(
            text: 'Can you come tomorrow?',
            sentAt: DateTime.now().subtract(const Duration(hours: 2)),
            isMine: true,
          ),
          ChatMessage(
            text: 'Yes, morning works.',
            sentAt: DateTime.now().subtract(const Duration(hours: 1)),
            isMine: false,
          ),
        ],
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
  }

  group('the repository', () {
    test('opening with somebody new starts a thread', () {
      final repository = ChatRepository(threads: []);

      expect(repository.hasThreadWith('Dev Electricals'), isFalse);
      final started = repository.openWith('Dev Electricals');

      expect(started.providerName, 'Dev Electricals');
      expect(started.messages, isEmpty);
      expect(repository.hasThreadWith('Dev Electricals'), isTrue);
      expect(repository.threads, hasLength(1));
    });

    test('opening with somebody they have spoken to reuses the thread', () {
      final repository = withThread();

      final opened = repository.openWith('Dev Electricals');

      expect(opened.messages, hasLength(2));
      expect(repository.threads, hasLength(1), reason: 'no second thread');
    });

    test('a started thread claims no reply time nobody measured', () {
      final repository = ChatRepository(threads: []);

      // The default on the model is "Usually replies in 10 min", which is a
      // number from the design rather than from the provider.
      expect(repository.openWith('Nobody').replyLine, '');
      expect(
        repository.openWith('Dev Electricals', replyLine: 'replies in 1 min')
            .replyLine,
        'replies in 1 min',
      );
    });
  });

  group('from the provider page', () {
    testWidgets('an existing conversation opens on what was said', (
      tester,
    ) async {
      final repository = withThread();

      await pump(
        tester,
        ChatsPage(
          repository: repository,
          openWith: const ChatOpenRequest(providerName: 'Dev Electricals'),
        ),
      );

      // The conversation, not the list: the composer only exists on one.
      expect(find.widgetWithText(TextField, 'Message'), findsOneWidget);
      expect(find.text('Yes, morning works.'), findsWidgets);
      expect(find.text('No messages yet'), findsNothing);
      // Opening it clears the badge.
      expect(repository.unreadCount, 0);
    });

    testWidgets('a new conversation opens and says nothing has been said', (
      tester,
    ) async {
      final repository = ChatRepository(threads: []);

      await pump(
        tester,
        ChatsPage(
          repository: repository,
          openWith: const ChatOpenRequest(
            providerName: 'Dev Electricals',
            replyLine: 'usually replies in 1 min',
          ),
        ),
      );

      expect(find.text('No messages yet'), findsOneWidget);
      expect(
        find.textContaining('Dev Electricals will pick it up here'),
        findsOneWidget,
      );
      expect(repository.hasThreadWith('Dev Electricals'), isTrue);
    });

    testWidgets('closing the thread lands on the list, with it on top', (
      tester,
    ) async {
      final repository = ChatRepository(threads: []);

      await pump(
        tester,
        ChatsPage(
          repository: repository,
          openWith: const ChatOpenRequest(providerName: 'Dev Electricals'),
        ),
      );
      // Back out of the conversation the request opened.
      Navigator.of(tester.element(find.text('No messages yet'))).pop();
      await tester.pumpAndSettle();

      // The list is behind it, and the thread just started is a row.
      expect(find.text('Chats'), findsOneWidget);
      expect(find.text('Dev Electricals'), findsWidgets);
    });

    testWidgets('coming to browse opens no conversation', (tester) async {
      final repository = withThread();

      await pump(tester, ChatsPage(repository: repository));

      // The list, not a thread: the composer is what only a conversation
      // has, and the badge is still there because nothing was read.
      expect(find.text('Chats'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Message'), findsNothing);
      expect(repository.unreadCount, 2);
    });
  });
}
