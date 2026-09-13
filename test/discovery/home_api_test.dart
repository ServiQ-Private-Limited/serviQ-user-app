import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/components/states/error_state.dart';
import 'package:local_markerplace/discovery/model/home_feed.dart';
import 'package:local_markerplace/discovery/presentation/discovery_home_view.dart';
import 'package:local_markerplace/network/failure.dart';

import '../support/fake_home_source.dart';

/// The body the endpoint actually returns for galleria-market-1.
const _payload = {
  'locality': {
    'slug': 'galleria-market-1',
    'name': 'Galleria Market 1',
    'localityType': 'MARKET',
    'zoneSlug': 'crossing-republik',
    'zoneName': 'Crossing Republik',
    'lat': 28.643,
    'lng': 77.442,
    'radiusKm': 0.30,
    'providerCount': 1,
  },
  'categories': [
    {
      'id': 1,
      'slug': 'home-repairs',
      'tradeName': 'Handyman',
      'needName': 'Home repairs & maintenance',
      'icon': 'wrench',
    },
    {
      'id': 6,
      'slug': 'ro-repair',
      'tradeName': 'RO Repair',
      'needName': 'Appliance repair',
      'icon': 'water',
    },
  ],
  'providersNearYou': [
    {
      'providerId': 'PRVDEV000001',
      'slug': 'dev-electricals',
      'name': 'Dev Electricals',
      'logoFileId': null,
      'verified': true,
      'openNow': true,
      'homeService': false,
      'responseTimeMinutes': null,
      'localityName': 'Galleria Market 1',
      'ratingAverage': 0,
      'reviewCount': 0,
    },
  ],
  'providerCount': 1,
};

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

Future<void> pumpHome(WidgetTester tester, FakeHomeSource source) async {
  tester.view.physicalSize = const Size(390 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true, fontFamily: 'Mulish'),
      home: Scaffold(
        body: SafeArea(
          bottom: false,
          child: DiscoveryHomeView(
            localityName: 'Galleria Market 1',
            localitySlug: 'galleria-market-1',
            homeRepository: source,
            onChangeLocality: () {},
            onSearch: () {},
            onSeeAllCategories: (_) {},
            onSeeAllProviders: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadFonts);

  group('before an area is known', () {
    testWidgets('home asks for nothing until it has one', (tester) async {
      final source = FakeHomeSource();
      tester.view.physicalSize = const Size(390 * 3, 900 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true, fontFamily: 'Mulish'),
          home: Scaffold(
            body: SafeArea(
              bottom: false,
              child: DiscoveryHomeView(
                // What the shell holds while it reads the stored profile.
                localityName: 'Choose your area',
                localitySlug: '',
                homeRepository: source,
                onChangeLocality: () {},
                onSearch: () {},
                onSeeAllCategories: (_) {},
                onSeeAllProviders: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 3));

      // An empty slug is not a question worth asking: the server answers it
      // with whichever area it defaults to, which is somebody else's.
      expect(source.requested, isEmpty);
      expect(find.byType(SkeletonList), findsOneWidget);
    });
  });

  group('the payload', () {
    test('parses the shape the endpoint sends', () {
      final feed = HomeFeed.fromJson(Map<String, dynamic>.from(_payload));

      expect(feed.locality.slug, 'galleria-market-1');
      expect(feed.locality.name, 'Galleria Market 1');
      expect(feed.locality.zoneName, 'Crossing Republik');
      expect(feed.locality.providerCount, 1);
      expect(feed.categories, hasLength(2));
      expect(feed.categories.first.tradeName, 'Handyman');
      expect(feed.categories.first.icon, 'wrench');
      expect(feed.providersNearYou.single.name, 'Dev Electricals');
      expect(feed.providersNearYou.single.verified, isTrue);
      // Zero reviews means unrated, which is not the same as rated zero.
      expect(feed.providersNearYou.single.isRated, isFalse);
    });

    test('survives nulls and missing lists', () {
      final feed = HomeFeed.fromJson(const {'locality': {}});

      expect(feed.categories, isEmpty);
      expect(feed.providersNearYou, isEmpty);
      expect(feed.providerCount, 0);
      expect(feed.locality.name, '');
    });
  });

  group('home', () {
    testWidgets('asks the endpoint for the area it was given', (tester) async {
      final source = FakeHomeSource();
      await pumpHome(tester, source);
      await tester.pumpAndSettle();

      expect(source.requested, ['galleria-market-1']);
    });

    testWidgets('waits behind a skeleton, never a spinner', (tester) async {
      final source = FakeHomeSource(delay: const Duration(milliseconds: 400));
      await pumpHome(tester, source);
      await tester.pump();

      expect(find.byType(SkeletonList), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Loading providers near you'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonList), findsNothing);
    });

    testWidgets('draws the categories and providers it was sent', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeSource(
          feed: HomeFeed.fromJson(Map<String, dynamic>.from(_payload)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Handyman'), findsOneWidget);
      expect(find.text('RO Repair'), findsOneWidget);
      expect(find.text('Dev Electricals'), findsOneWidget);
    });

    testWidgets('a server fault says it was not the seeker\'s doing', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeSource(
          failure: const Failure(
            errorMessage: 'Something went wrong',
            errorCode: 'INTERNAL_ERROR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.text("Couldn't load providers"), findsOneWidget);
      expect(find.textContaining('on our side, not yours'), findsOneWidget);
      // The code is quotable, so it is shown.
      expect(find.textContaining('quote ref INTERNAL_ERROR'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('being offline reads differently, and carries no ref', (
      tester,
    ) async {
      await pumpHome(
        tester,
        FakeHomeSource(
          failure: const Failure(
            errorMessage: 'No internet connection.',
            errorCode: 'CONNECTION_ERROR',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('You are offline'), findsOneWidget);
      // Nothing for support to chase — it is the connection, not the server.
      expect(find.textContaining('quote ref'), findsNothing);
    });

    testWidgets('retrying asks again', (tester) async {
      final source = FakeHomeSource(
        failure: const Failure(errorMessage: 'nope', errorCode: 'SERVER'),
      );
      await pumpHome(tester, source);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(source.requested, hasLength(2));
    });
  });
}
