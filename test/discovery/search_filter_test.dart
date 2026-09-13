import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/discovery/presentation/components/discovery_filter_chip.dart';
import 'package:local_markerplace/discovery/presentation/components/filter_button.dart';
import 'package:local_markerplace/discovery/presentation/components/search_filter_sheet.dart';
import 'package:local_markerplace/discovery/presentation/search_page.dart';

/// Search's filters, now behind one icon instead of two rails of chips.
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

/// The number the header quotes — "12 results in Ajnara Gen X · Plumber".
int resultCount(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .firstWhere((data) => RegExp(r'^\d+ results? in ').hasMatch(data));
  return int.parse(text.split(' ').first);
}

void main() {
  setUpAll(loadFonts);

  Future<void> pumpSearch(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Mulish'),
        home: const SearchPage(localityName: 'Ajnara Gen X'),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(find.byType(FilterButton));
    await tester.pumpAndSettle();
  }

  /// An area can carry a dozen trades, so the sections under them start
  /// below the fold — the same scroll a person would do.
  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.dragUntilVisible(
      target,
      find.byType(ListView).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the chips are gone and an icon stands in their place', (
    tester,
  ) async {
    await pumpSearch(tester);

    expect(find.byType(FilterButton), findsOneWidget);
    expect(find.byType(DiscoveryFilterChip), findsNothing);
    // Nothing narrowed yet, so the line names only the area.
    expect(find.textContaining('in Ajnara Gen X'), findsOneWidget);
    expect(find.textContaining('· Plumber'), findsNothing);
  });

  testWidgets('the sheet carries every scope the chips used to', (
    tester,
  ) async {
    await pumpSearch(tester);
    await openFilters(tester);

    expect(find.byType(SearchFilterSheet), findsOneWidget);
    // Trade, area and rating — the three the chip rails offered.
    expect(find.text('TRADE'), findsOneWidget);
    expect(find.text('All trades'), findsOneWidget);

    // Trade, area and rating — the three the chip rails offered.
    await scrollTo(tester, find.text('RATING'));
    expect(find.text('AREA'), findsOneWidget);
    expect(find.text('Any rating'), findsOneWidget);
    expect(find.text('4.0 and above'), findsOneWidget);
    // The area it is searching, named rather than left to be guessed.
    expect(find.text('Ajnara Gen X'), findsWidgets);
  });

  testWidgets('a trade and a rating are applied together', (tester) async {
    await pumpSearch(tester);
    final unfiltered = resultCount(tester);
    await openFilters(tester);

    await scrollTo(tester, find.text('Plumber'));
    await tester.tap(find.text('Plumber'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('4.0 and above'));
    await tester.tap(find.text('4.0 and above'));
    await tester.pumpAndSettle();
    // Nothing has happened to the list yet — the sheet holds both until it
    // is told to show the results.
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();

    expect(find.byType(SearchFilterSheet), findsNothing);
    expect(resultCount(tester), lessThan(unfiltered));
    // The line says what produced the count, since no chip does now.
    expect(find.textContaining('· Plumber · 4.0+'), findsOneWidget);

    final button = tester.widget<FilterButton>(find.byType(FilterButton));
    expect(button.isFiltered, isTrue);
  });

  testWidgets('clearing puts every result back', (tester) async {
    await pumpSearch(tester);
    final unfiltered = resultCount(tester);

    await openFilters(tester);
    await scrollTo(tester, find.text('Plumber'));
    await tester.tap(find.text('Plumber'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();
    expect(resultCount(tester), lessThan(unfiltered));

    await openFilters(tester);
    await tester.tap(find.text('Clear all'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show results'));
    await tester.pumpAndSettle();

    expect(resultCount(tester), unfiltered);
    expect(
      tester.widget<FilterButton>(find.byType(FilterButton)).isFiltered,
      isFalse,
    );
  });

  testWidgets('backing out of the sheet changes nothing', (tester) async {
    await pumpSearch(tester);
    await openFilters(tester);

    await scrollTo(tester, find.text('Plumber'));
    await tester.tap(find.text('Plumber'));
    await tester.pumpAndSettle();
    // Dismissed rather than applied: the trade tapped inside is forgotten.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.byType(SearchFilterSheet), findsNothing);
    expect(find.textContaining('· Plumber'), findsNothing);
    expect(
      tester.widget<FilterButton>(find.byType(FilterButton)).isFiltered,
      isFalse,
    );
  });

  testWidgets('the area row hands the screen back to the picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    // Pushed the way the shell pushes it, so popping has somewhere to land.
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, fontFamily: 'Mulish'),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        const SearchPage(localityName: 'Ajnara Gen X'),
                  ),
                ),
                child: const Text('open search'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open search'));
    await tester.pumpAndSettle();
    expect(find.byType(SearchPage), findsOneWidget);

    await openFilters(tester);
    await scrollTo(tester, find.text('AREA'));
    // The area row is the one that leads somewhere rather than choosing, so
    // it carries a chevron instead of a tick.
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pumpAndSettle();

    // Changing the area is the picker's job, so search steps aside rather
    // than filtering in place — what the locality chip used to do.
    expect(find.byType(SearchFilterSheet), findsNothing);
    expect(find.byType(SearchPage), findsNothing);
    expect(find.text('open search'), findsOneWidget);
  });
}
