import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/provider/model/provider_detail.dart';

import '../support/fake_provider_source.dart';
import '../provider/provider_api_test.dart' show capturedProvider, capturedReviews;

import 'package:local_markerplace/discovery/presentation/components/discovery_tab_bar.dart';
import 'package:local_markerplace/discovery/presentation/components/pending_booking_bar.dart';
import 'package:local_markerplace/discovery/presentation/discovery_shell.dart';
import 'package:local_markerplace/discovery/presentation/services_page.dart';
import 'package:local_markerplace/provider/presentation/components/segmented_tabs.dart';
import 'package:local_markerplace/provider/repository/provider_repository.dart';
import 'package:local_markerplace/provider/presentation/provider_profile_page.dart';
import 'package:local_markerplace/store/model/cart_product.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

const locality = 'Ajnara Gen X';

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

Future<void> pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Mulish'),
      home: screen,
    ),
  );
  await tester.pumpAndSettle();
}

/// The provider endpoints, answering with the payload they actually return.
FakeProviderSource providerSource() {
  Map<String, dynamic> dataOf(String raw) =>
      (jsonDecode(raw) as Map<String, dynamic>)['responseData']
          as Map<String, dynamic>;
  return FakeProviderSource(
    detail: ProviderDetail.fromJson(dataOf(capturedProvider)),
    reviewPage: ProviderReviewPage.fromJson(dataOf(capturedReviews)),
  );
}

void main() {
  setUpAll(loadFonts);

  // The shell and the provider profile read the session's singletons, so
  // every test starts from an empty basket and leaves one behind.
  setUp(VisitRepository.shared.clear);
  tearDown(VisitRepository.shared.clear);

  group('the basket bar', () {
    testWidgets('is absent until something is in it', (tester) async {
      await pump(tester, const DiscoveryShell(initialLocality: locality));

      expect(find.byType(PendingBookingBar), findsNothing);
    });

    testWidgets('follows the seeker across every tab', (tester) async {
      VisitRepository.shared.addService(
        providerName: 'Shahnaz RO & Chimney Services',
        providerLine: '$locality · usually replies in 10 min',
        service: const VisitService(
          name: 'RO Filter Change',
          detail: '',
          unitPrice: 349,
        ),
      );

      await pump(tester, const DiscoveryShell(initialLocality: locality));

      expect(find.byType(PendingBookingBar), findsOneWidget);
      // The bar names the store on top and the contents under it.
      expect(
        find.descendant(
          of: find.byType(PendingBookingBar),
          matching: find.text('Shahnaz RO & Chimney Services'),
        ),
        findsOneWidget,
      );
      expect(find.text('₹349 · 1 service'), findsOneWidget);

      for (final tab in [DiscoveryTab.explore, DiscoveryTab.me]) {
        await tester.tap(
          find.descendant(
            of: find.byType(DiscoveryTabBar),
            matching: find.text(_labelOf(tab)),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(PendingBookingBar),
          findsOneWidget,
          reason: 'the basket should still be reachable on $tab',
        );
      }
    });

    testWidgets('counts services and parts together for one provider', (
      tester,
    ) async {
      const provider = 'Shahnaz RO & Chimney Services';
      VisitRepository.shared.addService(
        providerName: provider,
        providerLine: locality,
        service: const VisitService(
          name: 'Chimney Deep Clean',
          detail: '',
          unitPrice: 899,
        ),
      );
      VisitRepository.shared.addProduct(
        providerName: provider,
        providerLine: locality,
        product: const CartProduct(
          name: 'Sediment Filter 10"',
          detail: '',
          unitPrice: 350,
          quantity: 2,
        ),
      );

      await pump(tester, const DiscoveryShell(initialLocality: locality));

      expect(find.text('₹1,599 · 1 service · 2 parts'), findsOneWidget);
    });
  });

  group('the services catalogue', () {
    testWidgets('lists every job and narrows to a category', (tester) async {
      await pump(tester, const ServicesPage(localityName: locality));

      const providers = ProviderRepository();
      final all = providers.servicesIn(locality);
      final plumbing = providers.servicesIn(locality, categoryLabel: 'Plumber');

      // The catalogue is the providers' own service lists flattened, so it
      // is as long as they make it.
      expect(all, isNotEmpty);
      expect(find.text('${all.length} jobs in $locality'), findsOneWidget);

      // The catalogue's filter is the sheet behind the header icon.
      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Plumber').last);
      await tester.pumpAndSettle();

      // The chip narrows the same flat list rather than opening a screen of
      // its own, and only plumbers survive it. The header names the filter
      // alongside the count, so a short list reads as narrowed.
      expect(plumbing, isNotEmpty);
      expect(plumbing.length, lessThan(all.length));
      expect(
        find.text('${plumbing.length} jobs in $locality · Plumber'),
        findsOneWidget,
      );
      for (final service in plumbing) {
        expect(service.categoryLabel, 'Plumber');
      }
    });

    testWidgets('adding puts the job in the cart and offers to undo it', (
      tester,
    ) async {
      await pump(tester, const ServicesPage(localityName: locality));

      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to cart'));
      await tester.pumpAndSettle();

      // The row now says the job is in the cart, with the bin to take it
      // out — a service is one job, so there is no count to step through.
      expect(find.text('In cart'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(VisitRepository.shared.current!.serviceCount, 1);

      // And the cart is in reach without leaving the list.
      expect(find.text('View cart'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(find.text('In cart'), findsNothing);
      expect(VisitRepository.shared.current, isNull);
      expect(find.text('View cart'), findsNothing);
    });
  });

  group('reaching the cart', () {
    testWidgets('the bar is on the page the part was added from', (
      tester,
    ) async {
      await pump(
        tester,
        ProviderProfilePage(
          slug: 'dev-electricals',
          initialTab: ProviderTab.store,
          localityName: locality,
          source: providerSource(),
        ),
      );

      // The provider's own page is a pushed route, not a tab of the shell —
      // it used to be the one place where things could be added and the cart
      // could not be reached.
      expect(find.byType(PendingBookingBar), findsNothing);

      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to cart · ₹349'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('My Cart'))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(PendingBookingBar), findsOneWidget);
      expect(find.textContaining('1 part'), findsWidgets);

      await tester.tap(find.text('View cart'));
      await tester.pumpAndSettle();

      expect(find.text('Review booking'), findsOneWidget);
      expect(find.text('1 part'), findsWidgets);
    });

    testWidgets('emptying the cart from the bar takes the bar away', (
      tester,
    ) async {
      VisitRepository.shared.addService(
        providerName: 'CoolAir AC Service',
        providerLine: locality,
        service: const VisitService(
          name: 'AC Servicing',
          detail: '',
          unitPrice: 499,
        ),
      );

      await pump(tester, const DiscoveryShell(initialLocality: locality));
      await tester.tap(find.text('View cart'));
      await tester.pumpAndSettle();

      // The cart's stepper wears a bin at one, and taking the last one off
      // empties the cart.
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('My Cart'))).pop();
      await tester.pumpAndSettle();

      expect(find.byType(PendingBookingBar), findsNothing);
    });
  });

  group('a part already in the cart', () {
    testWidgets('turns Add into a stepper that can delete it', (tester) async {
      await pump(
        tester,
        ProviderProfilePage(
          slug: 'dev-electricals',
          initialTab: ProviderTab.store,
          localityName: locality,
          source: providerSource(),
        ),
      );

      await tester.tap(find.text('Add').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to cart · ₹349'));
      await tester.pumpAndSettle();
      // Adding opens the cart; come back to the grid.
      Navigator.of(tester.element(find.text('My Cart'))).pop();
      await tester.pumpAndSettle();

      // The chip is now the count, with a bin because there is one of it.
      expect(find.text('1 in cart'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();

      // Two of them: the bin becomes a minus, because stepping down no
      // longer empties the line.
      expect(VisitRepository.shared.current!.partCount, 2);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(VisitRepository.shared.current, isNull);
      expect(find.text('Add'), findsWidgets);
    });
  });
}

String _labelOf(DiscoveryTab tab) => switch (tab) {
  DiscoveryTab.home => 'Home',
  DiscoveryTab.explore => 'Explore',
  DiscoveryTab.posts => 'Posts',
  DiscoveryTab.me => 'Me',
};
