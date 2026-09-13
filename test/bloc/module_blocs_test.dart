import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/basket/bloc/basket_bloc.dart';
import 'package:local_markerplace/chat/bloc/chats_bloc.dart';
import 'package:local_markerplace/chat/bloc/conversation_bloc.dart';
import 'package:local_markerplace/chat/repository/chat_repository.dart';
import 'package:local_markerplace/discovery/bloc/search_bloc.dart';
import 'package:local_markerplace/discovery/repository/discovery_repository.dart';
import 'package:local_markerplace/me/bloc/saved_providers_bloc.dart';
import 'package:local_markerplace/me/repository/me_repository.dart';
import 'package:local_markerplace/notifications/bloc/notification_bloc.dart';
import 'package:local_markerplace/network/failure.dart';

import '../support/fake_notification_repository.dart';
import 'package:local_markerplace/visit/bloc/visit_bloc.dart';
import 'package:local_markerplace/visit/model/visit_mode.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

/// The blocs the screens were moved onto, each exercised without a widget in
/// front of it.
void main() {
  /// Lets a bloc's handlers run before the state is read.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('notifications', () {
    test('a page is drawn and marking read empties the badge', () async {
      final repository = FakeNotificationRepository(
        pages: [samplePage(count: 3, hasNext: false)],
      );
      final bloc = NotificationBloc(notificationRepository: repository)
        ..add(const NotificationsRequested());
      await settle();

      expect(bloc.state.notifications, hasLength(3));
      expect(bloc.state.hasUnread, isTrue);
      expect(bloc.state.isLoading, isFalse);

      bloc.add(const AllNotificationsRead());
      await settle();

      expect(repository.markedRead, 1);
      expect(bloc.state.hasUnread, isFalse);
      expect(bloc.state.unreadCount, 0);
      await bloc.close();
    });

    test('the next page is appended rather than replacing the list', () async {
      final repository = FakeNotificationRepository(
        pages: [
          samplePage(count: 2, hasNext: true),
          samplePage(count: 2, page: 1, hasNext: false, startId: 100),
        ],
      );
      final bloc = NotificationBloc(notificationRepository: repository)
        ..add(const NotificationsRequested());
      await settle();
      expect(bloc.state.notifications, hasLength(2));
      expect(bloc.state.hasNext, isTrue);

      bloc.add(const NotificationsNextPageRequested());
      await settle();

      expect(bloc.state.notifications, hasLength(4));
      expect(bloc.state.page, 1);
      expect(bloc.state.hasNext, isFalse);
      // The pages asked for, in order — never the same one twice.
      expect(repository.requested, [0, 1]);
      await bloc.close();
    });

    test('asking past the last page does nothing', () async {
      final repository = FakeNotificationRepository(
        pages: [samplePage(count: 2, hasNext: false)],
      );
      final bloc = NotificationBloc(notificationRepository: repository)
        ..add(const NotificationsRequested());
      await settle();

      bloc.add(const NotificationsNextPageRequested());
      await settle();

      expect(repository.requested, [0]);
      await bloc.close();
    });

    test('a failed first page offers a retry that clears it', () async {
      final repository = FakeNotificationRepository(
        pages: [samplePage(count: 2, hasNext: false)],
        failFirst: const Failure(
          errorMessage: 'Service unavailable',
          errorCode: 'INTERNAL_ERROR',
        ),
      );
      final bloc = NotificationBloc(notificationRepository: repository)
        ..add(const NotificationsRequested());
      await settle();

      expect(bloc.state.failure?.errorCode, 'INTERNAL_ERROR');
      expect(bloc.state.failedAt, isNotNull);
      expect(bloc.state.isOffline, isFalse);

      bloc.add(const NotificationsRequested());
      await settle();

      expect(bloc.state.failure, isNull);
      expect(bloc.state.notifications, hasLength(2));
      await bloc.close();
    });

    test('a failed later page leaves what is on screen alone', () async {
      final repository = FakeNotificationRepository(
        pages: [samplePage(count: 2, hasNext: true)],
        failLater: const Failure(errorCode: 'CONNECTION_ERROR'),
      );
      final bloc = NotificationBloc(notificationRepository: repository)
        ..add(const NotificationsRequested());
      await settle();

      bloc.add(const NotificationsNextPageRequested());
      await settle();

      // The seeker scrolled to the bottom of a list that still reads fine.
      expect(bloc.state.notifications, hasLength(2));
      expect(bloc.state.failure, isNull);
      expect(bloc.state.isLoadingMore, isFalse);
      await bloc.close();
    });
  });

  group('chats', () {
    test('searching narrows the list without losing the threads', () async {
      final bloc = ChatsBloc(chatRepository: ChatRepository())
        ..add(const ChatsRequested());
      await settle();

      final all = bloc.state.threads.length;
      expect(all, greaterThan(1));

      bloc.add(ChatsSearched(bloc.state.threads.first.providerName));
      await settle();

      expect(bloc.state.results.length, lessThan(all));
      // The empty state is decided by the threads, not the results — a
      // search that matches nothing is not the same as having no chats.
      expect(bloc.state.threads, hasLength(all));
      expect(bloc.state.hasThreads, isTrue);
      await bloc.close();
    });

    test('opening a conversation clears its badge', () async {
      final chats = ChatRepository();
      final unread = chats.threads.firstWhere((t) => t.unreadCount > 0);

      final bloc = ConversationBloc(
        chatRepository: chats,
        visitRepository: VisitRepository(),
      )..add(ConversationOpened(unread.providerName));
      await settle();

      expect(bloc.state.thread?.unreadCount, 0);
      await bloc.close();
    });
  });

  group('the cart', () {
    VisitRepository filled() {
      final visits = VisitRepository();
      visits.addService(
        providerName: 'Dev Electricals',
        providerLine: 'Galleria Market 1',
        isVerifiedProvider: true,
        service: const VisitService(
          name: 'Fan Installation',
          detail: 'Ceiling or wall',
          unitPrice: 330,
        ),
      );
      return visits;
    }

    test('opening commits the tab it opens on as the mode', () async {
      final visits = filled();
      final bloc = VisitBloc(visitRepository: visits)
        ..add(const CartOpened('Dev Electricals'));
      await settle();

      // The tab is the mode, not a highlight over it: a seeker who agrees
      // with it never touches it, and the cart has to be bookable anyway.
      expect(bloc.state.tab, VisitMode.instant);
      expect(visits.cartFor('Dev Electricals')?.mode, VisitMode.instant);
      expect(bloc.state.cart?.isReady, isTrue);
      await bloc.close();
    });

    test('confirming books it and leaves the cart empty', () async {
      final visits = filled();
      final bloc = VisitBloc(visitRepository: visits)
        ..add(const CartOpened('Dev Electricals'));
      await settle();

      bloc.add(const CartConfirmed());
      await settle();

      expect(bloc.state.booked, isNotNull);
      expect(bloc.state.cart, isNull);
      expect(visits.booked, hasLength(1));
      await bloc.close();
    });

    test('the bar hears about a cart filled somewhere else', () async {
      final visits = VisitRepository();
      final bloc = BasketBloc(visitRepository: visits)
        ..add(const BasketRequested());
      await settle();

      expect(bloc.state.bar, isNull);

      // Added through the repository rather than through this bloc, the way
      // a provider's page does it.
      visits.addService(
        providerName: 'Dev Electricals',
        providerLine: 'Galleria Market 1',
        isVerifiedProvider: true,
        service: const VisitService(
          name: 'Fan Installation',
          detail: 'Ceiling or wall',
          unitPrice: 330,
        ),
      );
      await settle();

      expect(bloc.state.bar?.providerName, 'Dev Electricals');
      expect(bloc.state.cartCount, 1);
      await bloc.close();
    });
  });

  group('search', () {
    test('a trade narrows the results and All puts them back', () async {
      const repository = DiscoveryRepository();
      final bloc = SearchBloc(discoveryRepository: repository)
        ..add(const SearchOpened(localityName: 'Ajnara Gen X'));
      await settle();

      final all = bloc.state.results.length;
      expect(all, greaterThan(0));
      expect(bloc.state.trades, isNotEmpty);

      bloc.add(SearchTradeSelected(bloc.state.trades.first));
      await settle();
      expect(bloc.state.results.length, lessThan(all));

      bloc.add(const SearchTradeSelected(null));
      await settle();
      expect(bloc.state.results, hasLength(all));
      await bloc.close();
    });

    test('the rating chip cycles and comes back to any', () async {
      final bloc = SearchBloc(discoveryRepository: const DiscoveryRepository())
        ..add(const SearchOpened(localityName: 'Ajnara Gen X'));
      await settle();

      expect(bloc.state.ratingLabel, 'Any rating');
      bloc.add(const SearchRatingCycled());
      await settle();
      expect(bloc.state.ratingLabel, '4.0+');
      bloc.add(const SearchRatingCycled());
      await settle();
      expect(bloc.state.ratingLabel, '4.5+');
      bloc.add(const SearchRatingCycled());
      await settle();
      expect(bloc.state.ratingLabel, 'Any rating');
      await bloc.close();
    });
  });

  group('saved providers', () {
    test('the filter chooses between the three sets', () async {
      final bloc = SavedProvidersBloc(meRepository: const MeRepository())
        ..add(const SavedProvidersRequested('Ajnara Gen X'));
      await settle();

      expect(bloc.state.shown, bloc.state.providers);

      bloc.add(const SavedFilterSelected(SavedFilter.openNow));
      await settle();
      expect(bloc.state.shown, bloc.state.openNow);
      expect(bloc.state.shown.every((p) => p.isOpen), isTrue);
      await bloc.close();
    });
  });
}
