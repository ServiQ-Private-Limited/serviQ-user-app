import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/components/states/empty_state.dart';
import 'package:local_markerplace/components/states/error_state.dart';
import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/me/presentation/addresses_page.dart';
import 'package:local_markerplace/network/failure.dart';

import '../support/fake_address_repository.dart';

/// The addresses screen against the endpoint: what it draws while the list is
/// coming, when it arrives, when there is none and when it fails.
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

  /// The response as the live endpoint sent it, so a field the backend
  /// renames is caught here rather than on somebody's phone.
  List<Map<String, dynamic>> captured() {
    final raw =
        jsonDecode(File('test/fixtures/addresses.json').readAsStringSync())
            as Map<String, dynamic>;
    return [
      for (final entry in raw['responseData'] as List)
        Map<String, dynamic>.from(entry as Map),
    ];
  }

  /// Scoped to the list, because "Home" is also the name of a tab in the bar
  /// at the bottom of the screen.
  Finder inList(String text) =>
      find.descendant(of: find.byType(ListView), matching: find.text(text));

  Future<void> pump(
    WidgetTester tester,
    FakeAddressRepository repository, {
    Size size = const Size(390, 900),
  }) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Mulish'),
        home: AddressesPage(repository: repository),
      ),
    );
  }

  testWidgets('the screen waits on a skeleton, never a spinner', (
    tester,
  ) async {
    await pump(
      tester,
      FakeAddressRepository(
        saved: [sampleAddress()],
        delay: const Duration(milliseconds: 400),
      ),
    );
    await tester.pump();

    expect(find.byType(SkeletonList), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(SkeletonList), findsNothing);
  });

  testWidgets('every address the endpoint sent gets a card', (tester) async {
    final sent = captured();
    final repository = FakeAddressRepository(
      saved: [for (final json in sent) SavedAddress.fromJson(json)],
    );

    await pump(tester, repository);
    await tester.pumpAndSettle();

    expect(repository.requested, 1);
    // Twenty identical labels, because that is what the account holds.
    expect(find.text('Dispatch test'), findsWidgets);
    expect(
      find.text('A-1\nGalleria Market 1, 201016'),
      findsWidgets,
      reason: 'the parts should be joined the way the design breaks them',
    );
  });

  testWidgets('the default address is marked and comes first', (tester) async {
    final repository = FakeAddressRepository(
      saved: [
        sampleAddress(id: 17, label: 'Office'),
        sampleAddress(id: 16, label: 'Home', isDefault: true),
      ],
    );

    await pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('DEFAULT'), findsOneWidget);
    // Exactly one card offers to become the default — the other already is.
    expect(find.text('Set as default'), findsOneWidget);
    expect(
      tester.getTopLeft(inList('Home')).dy,
      lessThan(tester.getTopLeft(inList('Office')).dy),
    );
  });

  testWidgets('an account with nothing saved says so, and offers a way out', (
    tester,
  ) async {
    await pump(tester, FakeAddressRepository());
    await tester.pumpAndSettle();

    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.text('No addresses saved yet'), findsOneWidget);
    expect(find.text('Add an address'), findsOneWidget);
  });

  testWidgets('a failure offers a retry that loads the list', (tester) async {
    final repository = FakeAddressRepository(
      saved: [sampleAddress(label: 'Home')],
      failFirst: const Failure(
        errorMessage: 'Something went wrong.',
        errorCode: 'INTERNAL_ERROR',
      ),
    );

    await pump(tester, repository);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorState), findsOneWidget);
    expect(find.text("Couldn't load your addresses"), findsOneWidget);
    // The reference is what a support conversation has to quote.
    expect(find.textContaining('INTERNAL_ERROR'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repository.requested, 2);
    expect(find.byType(ErrorState), findsNothing);
    expect(inList('Home'), findsOneWidget);
  });

  testWidgets('being offline reads differently from a server fault', (
    tester,
  ) async {
    await pump(
      tester,
      FakeAddressRepository(
        failFirst: const Failure(
          errorMessage: 'No internet connection.',
          errorCode: 'CONNECTION_ERROR',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('You are offline'), findsOneWidget);
    // Not the seeker's fault to report, so no reference to quote.
    expect(find.textContaining('CONNECTION_ERROR'), findsNothing);
  });

  group('the payload', () {
    test('parses the way the endpoint sends it', () {
      final sent = captured();
      final parsed = [for (final json in sent) SavedAddress.fromJson(json)];

      expect(parsed.length, 20);
      expect(parsed.first.id, 16);
      expect(parsed.first.isDefault, isTrue);
      expect(parsed.where((a) => a.isDefault), hasLength(1));
      expect(parsed.first.localitySlug, 'galleria-market-1');
      expect(parsed.first.pincode, '201016');
      expect(parsed.first.lat, isNull);
    });

    test('a null line or landmark closes up rather than leaving a comma', () {
      final address = sampleAddress(line1: 'A-1');

      expect(address.street, 'A-1');
      expect(address.lines, 'A-1\nGalleria Market 1, 201016');
    });

    test('every part the seeker typed is kept in order', () {
      final address = sampleAddress(
        line1: 'Tower B, Flat 1204',
        line2: 'Sector 4',
        landmark: 'Opposite the community hall',
      );

      expect(
        address.street,
        'Tower B, Flat 1204, Sector 4, Opposite the community hall',
      );
    });

    test('an address with no label of its own still has a heading', () {
      expect(sampleAddress(label: '').displayLabel, 'Galleria Market 1');
    });

    test('coordinates survive whether they are sent whole or not', () {
      final pinned = SavedAddress.fromJson({
        'label': 'Home',
        'lat': 28,
        'lng': 77.3910,
      });

      expect(pinned.lat, 28.0);
      expect(pinned.lng, closeTo(77.3910, 0.0001));
    });
  });

  for (final size in const [
    Size(320, 568),
    Size(360, 640),
    Size(428, 926),
  ]) {
    testWidgets(
      'Addresses fits ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        await pump(
          tester,
          FakeAddressRepository(
            saved: [
              sampleAddress(label: 'Home', isDefault: true),
              sampleAddress(id: 17, label: 'Office'),
            ],
          ),
          size: size,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }
}
