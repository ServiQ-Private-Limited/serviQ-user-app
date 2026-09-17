import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/components/states/error_state.dart';
import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/provider/model/provider_detail.dart';
import 'package:local_markerplace/provider/presentation/components/segmented_tabs.dart';
import 'package:local_markerplace/provider/presentation/provider_profile_page.dart';

import '../support/fake_provider_source.dart';
import 'provider_api_test.dart' show capturedProvider, capturedReviews;

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

/// The provider's page, drawn from the payloads the endpoints return.
void main() {
  setUpAll(loadFonts);

  Map<String, dynamic> dataOf(String raw) =>
      (jsonDecode(raw) as Map<String, dynamic>)['responseData']
          as Map<String, dynamic>;

  ProviderDetail detail() => ProviderDetail.fromJson(dataOf(capturedProvider));

  FakeProviderSource source({
    ProviderDetail? provider,
    Failure? profileFailure,
    Failure? productsFailure,
    Duration delay = Duration.zero,
  }) {
    return FakeProviderSource(
      detail: profileFailure == null ? (provider ?? detail()) : null,
      reviewPage: ProviderReviewPage.fromJson(dataOf(capturedReviews)),
      profileFailure: profileFailure,
      productsFailure: productsFailure,
      delay: delay,
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget screen, {
    Size? size,
    bool settle = true,
  }) async {
    final target = size ?? const Size(390, 844);
    tester.view.physicalSize = target * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    if (settle) {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  }

  testWidgets('the page waits on a skeleton, never a spinner', (tester) async {
    await pump(
      tester,
      ProviderProfilePage(
        slug: 'dev-electricals',
        source: source(delay: const Duration(milliseconds: 400)),
      ),
      settle: false,
    );
    await tester.pump();

    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Dev Electricals'), findsOneWidget);
  });

  testWidgets('a signed-out visitor can read the page but not act on it', (
    tester,
  ) async {
    await pump(
      tester,
      ProviderProfilePage(
        slug: 'dev-electricals',
        isSignedIn: false,
        source: source(),
      ),
    );

    expect(find.text('Dev Electricals'), findsOneWidget);
    expect(find.text('VERIFIED'), findsOneWidget);
    expect(find.text('Sign in to connect'), findsOneWidget);
    expect(find.text('Sign in to chat'), findsOneWidget);
    expect(find.textContaining('This page is public'), findsOneWidget);
  });

  testWidgets('signing in turns the gated actions into real ones', (
    tester,
  ) async {
    await pump(
      tester,
      ProviderProfilePage(slug: 'dev-electricals', source: source()),
    );

    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Chat'), findsOneWidget);
    expect(find.textContaining('This page is public'), findsNothing);
  });

  testWidgets('opening a tab asks that tab own endpoint', (tester) async {
    final fake = source();
    await pump(
      tester,
      ProviderProfilePage(slug: 'dev-electricals', source: fake),
    );

    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Services'));
    await tester.pumpAndSettle();

    // Opening a section refreshes it, which is what the per-tab endpoints
    // are for — seeded content nothing ever refreshed would mean three
    // endpoints the app never called.
    expect(fake.asked, contains('products:dev-electricals'));
    expect(fake.asked, contains('availability:dev-electricals'));
    expect(fake.asked, contains('services:dev-electricals'));
  });

  testWidgets('each tab shows what its endpoint returned', (tester) async {
    await pump(
      tester,
      ProviderProfilePage(slug: 'dev-electricals', source: source()),
    );

    // Services — the names and prices the endpoint sent.
    expect(find.text('AC servicing'), findsOneWidget);
    expect(find.text('from ₹599'), findsOneWidget);

    await tester.tap(find.text('Reviews'));
    await tester.pumpAndSettle();
    // Unrated, and the page says so rather than drawing empty stars.
    expect(find.text('No reviews yet.'), findsOneWidget);

    await tester.tap(find.text('About'));
    await tester.pumpAndSettle();
    expect(find.text('ADDRESS'), findsOneWidget);
    expect(find.text('HOURS'), findsOneWidget);
    expect(find.text('SERVES'), findsOneWidget);
    expect(
      find.textContaining('Seeded partner for the DEV environment.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
    expect(find.text('Extension board'), findsOneWidget);
    // The count the endpoint gave, not a judgement about it.
    expect(find.text('7 in stock'), findsOneWidget);
  });

  testWidgets('a provider with no services says so', (tester) async {
    final bare = ProviderDetail.fromJson({
      ...dataOf(capturedProvider),
      'services': const [],
      'products': const [],
    });

    await pump(
      tester,
      ProviderProfilePage(
        slug: 'dev-electricals',
        source: source(provider: bare),
      ),
    );

    expect(find.text('This provider lists no services.'), findsOneWidget);

    await tester.tap(find.text('Store'));
    await tester.pumpAndSettle();
    expect(find.text('This provider sells no parts.'), findsOneWidget);
  });

  testWidgets('a provider that is not there is said plainly', (tester) async {
    await pump(
      tester,
      ProviderProfilePage(
        slug: 'no-such-shop',
        source: source(
          profileFailure: const Failure(
            errorMessage: 'Provider not found.',
            errorCode: 'PROVIDER_NOT_FOUND',
          ),
        ),
      ),
    );

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text('That provider is not here'), findsOneWidget);
    // Not our fault to apologise for, so no reference to quote.
    expect(find.textContaining('PROVIDER_NOT_FOUND'), findsNothing);
  });

  testWidgets('one tab failing leaves the rest of the page readable', (
    tester,
  ) async {
    await pump(
      tester,
      ProviderProfilePage(
        slug: 'dev-electricals',
        source: source(
          productsFailure: const Failure(
            errorMessage: 'Something went wrong.',
            errorCode: 'INTERNAL_ERROR',
          ),
        ),
      ),
    );

    // The About payload seeded the store, so the tab reads until it is
    // asked to refresh — the provider itself is never taken away.
    expect(find.text('Dev Electricals'), findsOneWidget);
    expect(find.text('AC servicing'), findsOneWidget);
  });

  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(390, 844),
    Size(428, 926),
  ]) {
    for (final tab in ProviderTab.values) {
      testWidgets('the ${tab.label} tab fits ${size.width.toInt()}x'
          '${size.height.toInt()}', (tester) async {
        await pump(
          tester,
          ProviderProfilePage(
            slug: 'dev-electricals',
            initialTab: tab,
            source: source(),
          ),
          size: size,
        );
      });
    }
  }
}
