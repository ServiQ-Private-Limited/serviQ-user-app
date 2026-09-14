import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/core/app_color.dart';
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
    final raw = jsonDecode(capturedAddresses) as Map<String, dynamic>;
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

  group('deleting an address', () {
    testWidgets('asks first, because it cannot be undone', (tester) async {
      final repository = FakeAddressRepository(
        saved: [sampleAddress(id: 16, label: 'Home', isDefault: true)],
      );
      await pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(inList('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Home?'), findsOneWidget);
      await tester.tap(find.text('Keep it'));
      await tester.pumpAndSettle();

      expect(repository.deleted, isEmpty, reason: 'nothing was confirmed');
      expect(inList('Home'), findsOneWidget);
    });

    testWidgets('confirming removes it and redraws the list', (tester) async {
      final repository = FakeAddressRepository(
        saved: [
          sampleAddress(id: 16, label: 'Home', isDefault: true),
          sampleAddress(id: 17, label: 'Office'),
        ],
      );
      await pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(inList('Delete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(repository.deleted, [16]);
      expect(inList('Home'), findsNothing);
      expect(inList('Office'), findsOneWidget);
    });

    testWidgets('deleting the default leaves another one marked', (
      tester,
    ) async {
      final repository = FakeAddressRepository(
        saved: [
          sampleAddress(id: 16, label: 'Home', isDefault: true),
          sampleAddress(id: 17, label: 'Office'),
        ],
      );
      await pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(inList('Delete').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      // The server promotes one; the screen has to show that rather than
      // leaving the seeker with no default at all.
      expect(find.text('DEFAULT'), findsOneWidget);
      expect(find.text('Set as default'), findsNothing);
    });

    testWidgets('the row says it is going while the server is told', (
      tester,
    ) async {
      final repository = FakeAddressRepository(
        saved: [sampleAddress(id: 16, label: 'Home', isDefault: true)],
        delay: const Duration(milliseconds: 400),
      );
      await pump(tester, repository);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(inList('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pump();

      expect(find.text('Deleting…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });

    testWidgets('a refused delete keeps the row and says why', (tester) async {
      final repository = FakeAddressRepository(
        saved: [sampleAddress(id: 16, label: 'Home', isDefault: true)],
      )..failDelete = const Failure(
          errorMessage: 'Something went wrong.',
          errorCode: 'INTERNAL_ERROR',
        );
      await pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(inList('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(inList('Home'), findsOneWidget, reason: 'it is still there');
      // The server's own words are what tell the seeker anything useful.
      expect(find.textContaining('Something went wrong.'), findsOneWidget);
    });
  });

  group('the actions on a card', () {
    testWidgets('are coloured as actions, not as disabled text', (
      tester,
    ) async {
      await pump(
        tester,
        FakeAddressRepository(
          saved: [
            sampleAddress(id: 16, label: 'Home', isDefault: true),
            sampleAddress(id: 17, label: 'Office'),
          ],
        ),
      );
      await tester.pumpAndSettle();

      Color colourOf(String label) =>
          tester.widget<Text>(inList(label).first).style!.color!;

      // The muted greys the design uses for secondary and disabled text.
      // Drawing an action in either is what made every one of these look
      // switched off.
      const deadGreys = [
        AppColor.discoveryTextTertiary,
        AppColor.discoveryTextDisabled,
      ];

      for (final action in ['Edit', 'Delete', 'Set as default']) {
        expect(
          deadGreys,
          isNot(contains(colourOf(action))),
          reason: '"$action" is drawn in a disabled grey',
        );
      }
      expect(colourOf('Edit'), AppColor.discoveryAccent);
      expect(colourOf('Set as default'), AppColor.discoveryAccent);
      // Deleting cannot be undone, so it is coloured as the one that bites.
      expect(colourOf('Delete'), AppColor.authError);
    });

    testWidgets('are big enough to aim at', (tester) async {
      await pump(
        tester,
        FakeAddressRepository(
          saved: [sampleAddress(id: 16, label: 'Home', isDefault: true)],
        ),
      );
      await tester.pumpAndSettle();

      for (final action in ['Edit', 'Delete']) {
        final target = find.ancestor(
          of: inList(action),
          matching: find.byType(PressableScale),
        );
        expect(target, findsOneWidget, reason: '"$action" should press');
        expect(
          tester.getSize(target).height,
          greaterThanOrEqualTo(32),
          reason: '"$action" is a small thing to hit',
        );
      }
    });

    testWidgets('grey out only while the server is being told', (
      tester,
    ) async {
      await pump(
        tester,
        FakeAddressRepository(
          saved: [
            sampleAddress(id: 16, label: 'Home', isDefault: true),
            sampleAddress(id: 17, label: 'Office'),
          ],
          delay: const Duration(milliseconds: 400),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set as default'));
      await tester.pump();

      expect(
        tester.widget<Text>(find.text('Setting…')).style!.color,
        AppColor.discoveryTextTertiary,
        reason: 'in flight is the one moment it is genuinely inert',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });
  });

  group('setting the default', () {
    testWidgets('promotes the one tapped and demotes the old one', (
      tester,
    ) async {
      final repository = FakeAddressRepository(
        saved: [
          sampleAddress(id: 16, label: 'Home', isDefault: true),
          sampleAddress(id: 17, label: 'Office'),
        ],
      );
      await pump(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set as default'));
      await tester.pumpAndSettle();

      expect(repository.promoted, [17]);
      expect(find.text('DEFAULT'), findsOneWidget);
      // The promoted one is now first, and the old default offers the action.
      expect(
        tester.getTopLeft(inList('Office')).dy,
        lessThan(tester.getTopLeft(inList('Home')).dy),
      );
      expect(find.text('Set as default'), findsOneWidget);
    });

    testWidgets('never asks twice — the endpoint toggles', (tester) async {
      final repository = FakeAddressRepository(
        saved: [
          sampleAddress(id: 16, label: 'Home', isDefault: true),
          sampleAddress(id: 17, label: 'Office'),
        ],
        delay: const Duration(milliseconds: 300),
      );
      await pump(tester, repository);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Two taps in quick succession. A second call would clear the default
      // the first one just set, leaving the account with none.
      await tester.tap(find.text('Set as default'));
      await tester.pump();
      await tester.tap(find.text('Setting…'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repository.promoted, [17], reason: 'exactly one call');
      expect(find.text('DEFAULT'), findsOneWidget);
    });

    testWidgets('the default row does not offer the action at all', (
      tester,
    ) async {
      await pump(
        tester,
        FakeAddressRepository(
          saved: [sampleAddress(id: 16, label: 'Home', isDefault: true)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Set as default'), findsNothing);
    });
  });

  group('editing an address', () {
    testWidgets('opens on what is already saved', (tester) async {
      await pump(
        tester,
        FakeAddressRepository(
          saved: [
            sampleAddress(
              id: 16,
              label: 'Home',
              line1: 'A-1',
              line2: 'Tower B',
              isDefault: true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(inList('Edit'));
      await tester.pumpAndSettle();

      expect(find.text('Edit address'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      // Prefilled, so a seeker changes one field rather than retyping.
      expect(find.widgetWithText(TextField, 'A-1'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Tower B'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Home'), findsOneWidget);
    });

    testWidgets('an address with no pin gets no map and says so', (
      tester,
    ) async {
      // lat/lng come back null for anything the API created; nothing here
      // invents coordinates to put a map on.
      await pump(
        tester,
        FakeAddressRepository(
          saved: [sampleAddress(id: 16, label: 'Home', isDefault: true)],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(inList('Edit'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('no map pin saved against it'),
        findsOneWidget,
      );
      expect(find.text('Change'), findsNothing);
    });
  });

  group('when the endpoint marks no default', () {
    // The captured response has isDefault false on all three. The app must
    // not pick one itself — a seeker whose account has no default was being
    // told, on the cart, that a provider was coming to whichever address
    // happened to be first in the list.
    List<SavedAddress> noneDefault() => [
      for (final json in captured()) SavedAddress.fromJson(json),
    ];

    test('no address is offered as the default', () async {
      final repository = FakeAddressRepository(saved: noneDefault());
      await repository.addresses();

      expect(repository.loaded.where((a) => a.isDefault), isEmpty);
      expect(
        repository.defaultAddress,
        isNull,
        reason: 'the first in the list is not the default',
      );
    });

    testWidgets('no card claims to be the default', (tester) async {
      await pump(tester, FakeAddressRepository(saved: noneDefault()));
      await tester.pumpAndSettle();

      expect(find.text('DEFAULT'), findsNothing);
      // Every one of them can be made the default instead.
      expect(find.text('Set as default'), findsNWidgets(3));
    });
  });

  group('the payload', () {
    test('parses the way the endpoint sends it', () {
      final sent = captured();
      final parsed = [for (final json in sent) SavedAddress.fromJson(json)];

      expect(parsed.length, 3);
      expect(parsed.first.id, 103);
      expect(parsed.first.label, 'Work');
      // None of them is the default, and the app does not pick one.
      expect(parsed.where((a) => a.isDefault), isEmpty);
      expect(parsed.first.localitySlug, 'galleria-market-1');
      expect(parsed.first.pincode, '201016');
      // Created through the API rather than the map, so there is no pin.
      expect(parsed.first.lat, isNull);

      // A second locality in the same list, which the card shows as its own.
      final ajnara = parsed.last;
      expect(ajnara.localitySlug, 'ajnara-gen-x');
      expect(ajnara.localityName, 'Ajnara Gen X');
      expect(ajnara.landmark, 'Opposite the clubhouse');
      expect(ajnara.street, 'A-101, Ajnara Gen X, Opposite the clubhouse');
      expect(ajnara.area, 'Ajnara Gen X, 201016');
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

/// `/api/v1/user/addresses` as the live endpoint answered it, captured whole.
///
/// Inline rather than in a fixtures directory for the same reason as the
/// notifications page: a data file that is not committed alongside its test
/// takes the test down with it.
const capturedAddresses = r'''
{
  "responseCode": "200 OK",
  "errorCode": null,
  "responseMessage": "Success",
  "responseTime": "2026-09-14T10:00:12.541427916Z",
  "responseData": [
    {
      "id": 103,
      "label": "Work",
      "line1": "A-1",
      "line2": null,
      "landmark": null,
      "localitySlug": "galleria-market-1",
      "localityName": "Galleria Market 1",
      "pincode": "201016",
      "lat": null,
      "lng": null,
      "isDefault": false
    },
    {
      "id": 105,
      "label": "Dispatch test",
      "line1": "A-1",
      "line2": null,
      "landmark": null,
      "localitySlug": "galleria-market-1",
      "localityName": "Galleria Market 1",
      "pincode": "201016",
      "lat": null,
      "lng": null,
      "isDefault": false
    },
    {
      "id": 175,
      "label": "Home",
      "line1": "A-101, Ajnara Gen X",
      "line2": null,
      "landmark": "Opposite the clubhouse",
      "localitySlug": "ajnara-gen-x",
      "localityName": "Ajnara Gen X",
      "pincode": "201016",
      "lat": null,
      "lng": null,
      "isDefault": false
    }
  ]
}
''';
