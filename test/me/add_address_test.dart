import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/me/bloc/pick_location_bloc.dart';
import 'package:local_markerplace/me/bloc/save_address_bloc.dart';
import 'package:local_markerplace/me/model/address_draft.dart';
import 'package:local_markerplace/network/failure.dart';

import 'package:local_markerplace/me/repository/place_lookup.dart';

import '../support/fake_address_repository.dart';
import '../support/fake_place_lookup.dart';

/// Adding an address: the map step, then the details step.
///
/// The blocs are tested rather than the screens, because the screens embed a
/// GoogleMap — a platform view with no widget-test implementation — and what
/// is worth pinning here is the decisions, not the tiles.
void main() {
  const draft = AddressDraft(
    latitude: 28.6412,
    longitude: 77.3910,
    placeName: 'Shakti Khand',
    formattedAddress: '766, Shakti Khand 4, Indirapuram, Ghaziabad',
  );

  group('picking the location', () {
    test('opens on the seeker, with the address read back', () async {
      final lookup = FakePlaceLookup();
      final bloc = PickLocationBloc(placeLookup: lookup);

      bloc.add(const PickLocationStarted());
      await bloc.stream.firstWhere((state) => !state.isLocating);

      expect(lookup.hereCalls, 1);
      expect(bloc.state.draft?.placeName, 'Shakti Khand');
      expect(bloc.state.canConfirm, isTrue);
      // The map is told to move, because the seeker did not move it.
      expect(bloc.state.recentre, isTrue);
      await bloc.close();
    });

    test('a refused location still leaves somewhere to drag from', () async {
      final bloc = PickLocationBloc(
        placeLookup: FakePlaceLookup(
          hereFails: const Failure(
            errorMessage: 'ServiQ has not been allowed to use your location.',
            errorCode: 'LOCATION_DENIED',
          ),
        ),
      );

      bloc.add(const PickLocationStarted());
      await bloc.stream.firstWhere((state) => !state.isLocating);

      expect(bloc.state.failure?.errorCode, 'LOCATION_DENIED');
      // A map with no centre is a map nobody can use.
      expect(bloc.state.draft, isNotNull);
      await bloc.close();
    });

    test('dragging the map looks the new spot up', () async {
      final lookup = FakePlaceLookup();
      final bloc = PickLocationBloc(placeLookup: lookup);

      bloc.add(const PickLocationStarted());
      await bloc.stream.firstWhere((state) => !state.isLocating);

      bloc.add(const PinMoved(latitude: 28.65, longitude: 77.40));
      await bloc.stream.firstWhere(
        (state) => !state.isResolving && state.draft?.latitude == 28.65,
      );

      expect(lookup.resolved.last, (28.65, 77.40));
      // The seeker moved the map, so nothing moves it back under them.
      expect(bloc.state.recentre, isFalse);
      await bloc.close();
    });

    test('a pin with no address behind it cannot be confirmed', () {
      final bloc = PickLocationBloc(placeLookup: FakePlaceLookup());

      expect(bloc.state.canConfirm, isFalse);
      bloc.close();
    });

    test('opening on an existing address starts there, not at the GPS', () async {
      final lookup = FakePlaceLookup();
      final bloc = PickLocationBloc(placeLookup: lookup);

      bloc.add(const PickLocationStarted(startAt: draft));
      await bloc.stream.firstWhere((state) => !state.isResolving);

      expect(lookup.hereCalls, 0, reason: 'it already knows where to look');
      expect(lookup.resolved.single, (28.6412, 77.3910));
      await bloc.close();
    });

    test('choosing a search result moves the map to it', () async {
      const found = AddressDraft(
        latitude: 28.70,
        longitude: 77.10,
        placeName: 'Karol Bagh',
        formattedAddress: 'Karol Bagh, New Delhi',
      );
      final bloc = PickLocationBloc(
        placeLookup: FakePlaceLookup(results: const [found]),
      );

      bloc.add(const LocationSearched('karol'));
      await bloc.stream.firstWhere((state) => state.results.isNotEmpty);
      bloc.add(const SearchResultChosen(found));
      await bloc.stream.firstWhere((state) => state.results.isEmpty);

      expect(bloc.state.draft, found);
      expect(bloc.state.recentre, isTrue);
      await bloc.close();
    });
  });

  group('reading an address off the map', () {
    test('the geocoder repeating itself is said once', () {
      // Exactly what a real Ghaziabad fix returned: name repeated inside
      // street, and every later field repeated inside it again.
      final line = DevicePlaceLookup.formatParts([
        'Sachin Home',
        'Sachin Home, Mahiuddin Pur Kanawni, Balaji Colony, Ghaziabad, '
            'Uttar Pradesh 201014, India',
        'Balaji Colony',
        'Ghaziabad',
        'Meerut Division',
        'Uttar Pradesh',
        '201014',
        'India',
      ]);

      expect(
        line,
        'Sachin Home, Mahiuddin Pur Kanawni, Balaji Colony, Ghaziabad, '
        'Uttar Pradesh 201014, India, Meerut Division',
      );
      expect('Sachin Home'.allMatches(line), hasLength(1));
      expect('Balaji Colony'.allMatches(line), hasLength(1));
      expect('India'.allMatches(line), hasLength(1));
    });

    test('a tidy placemark keeps every part, in order', () {
      expect(
        DevicePlaceLookup.formatParts([
          '766',
          'Shakti Khand 4',
          'Indirapuram',
          'Ghaziabad',
          null,
          'Uttar Pradesh',
          '201014',
          'India',
        ]),
        '766, Shakti Khand 4, Indirapuram, Ghaziabad, Uttar Pradesh, '
        '201014, India',
      );
    });

    test('blanks close up rather than leaving stray commas', () {
      expect(DevicePlaceLookup.formatParts([null, '', '  ']), '');
      expect(DevicePlaceLookup.formatParts(['A-1', '', 'Ghaziabad']),
          'A-1, Ghaziabad');
    });
  });

  group('the details step', () {
    SaveAddressBloc blocFor(FakeAddressRepository repository) =>
        SaveAddressBloc(
          addressRepository: repository,
          draft: draft,
          localitySlug: 'galleria-market-1',
        );

    test('needs a door and a name before it can save', () async {
      final bloc = blocFor(FakeAddressRepository());

      expect(bloc.state.canSave, isFalse);
      bloc.add(const HouseChanged('A-1'));
      await bloc.stream.first;
      expect(bloc.state.canSave, isFalse, reason: 'still unnamed');

      bloc.add(const LabelChanged('Home'));
      await bloc.stream.first;
      expect(bloc.state.canSave, isTrue);
      await bloc.close();
    });

    test('a chosen chip fills the name in', () async {
      final bloc = blocFor(FakeAddressRepository());

      bloc.add(const LabelSuggestionChosen('Office'));
      await bloc.stream.first;

      expect(bloc.state.label, 'Office');
      await bloc.close();
    });

    test('saving sends the pin, the door and the chosen area', () async {
      final repository = FakeAddressRepository();
      final bloc = blocFor(repository);

      bloc.add(const HouseChanged('A-1'));
      bloc.add(const BuildingChanged('Tower B'));
      bloc.add(const LabelChanged('Home'));
      await bloc.stream.firstWhere((state) => state.canSave);

      bloc.add(const AddressSubmitted(makeDefault: true));
      await bloc.stream.firstWhere((state) => state.saved != null);

      final sent = repository.created.single;
      expect(sent['line1'], 'A-1');
      expect(sent['line2'], 'Tower B');
      expect(sent['label'], 'Home');
      // The area is the one already chosen, not one read off the map: the
      // endpoint refuses a slug it does not know.
      expect(sent['localitySlug'], 'galleria-market-1');
      expect(sent['lat'], 28.6412);
      expect(sent['lng'], 77.3910);
      expect(sent['isDefault'], isTrue);
      // What the geocoder read is kept, because it is the only record of the
      // street the pin actually landed on.
      expect(sent['landmark'], draft.formattedAddress);
      await bloc.close();
    });

    test('a refused save says so and stays on the form', () async {
      final repository = FakeAddressRepository()
        ..failCreate = const Failure(
          errorMessage: 'That locality does not exist.',
          errorCode: 'LOCALITY_NOT_FOUND',
        );
      final bloc = blocFor(repository);

      bloc.add(const HouseChanged('A-1'));
      bloc.add(const LabelChanged('Home'));
      await bloc.stream.firstWhere((state) => state.canSave);

      bloc.add(const AddressSubmitted());
      await bloc.stream.firstWhere((state) => state.failure != null);

      expect(bloc.state.saved, isNull);
      expect(bloc.state.failure?.errorCode, 'LOCALITY_NOT_FOUND');
      expect(bloc.state.isSaving, isFalse);
      await bloc.close();
    });

    test('an address saved with no known area still keeps its pin', () async {
      final repository = FakeAddressRepository();
      final bloc = SaveAddressBloc(
        addressRepository: repository,
        draft: draft,
      );

      bloc.add(const HouseChanged('A-1'));
      bloc.add(const LabelChanged('Mum'));
      await bloc.stream.firstWhere((state) => state.canSave);
      bloc.add(const AddressSubmitted());
      await bloc.stream.firstWhere((state) => state.saved != null);

      final sent = repository.created.single;
      expect(sent['localitySlug'], isNull);
      expect(sent['lat'], 28.6412);
      await bloc.close();
    });
  });
}
