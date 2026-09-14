import 'package:dartz/dartz.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import 'package:geolocator/geolocator.dart';

import 'package:local_markerplace/me/model/address_draft.dart';
import 'package:local_markerplace/network/failure.dart';

/// Turning a point on the map into words, and words into a point.
///
/// An interface rather than the plugins directly, so the screens can be
/// pumped without a device under them — a test of the address form is not a
/// test of Android's geocoder.
abstract class PlaceLookup {
  /// Where the seeker is, with the address read back.
  Future<Either<Failure, AddressDraft>> here();

  /// What is at these coordinates. Used when the pin is dragged.
  Future<Either<Failure, AddressDraft>> at({
    required double latitude,
    required double longitude,
  });

  /// Places matching what was typed into the search field.
  Future<Either<Failure, List<AddressDraft>>> search(String query);
}

/// [PlaceLookup] against the device.
///
/// Both halves are the platform's own — `geolocator` for the fix and
/// Android's / iOS's built-in geocoder for the words. Neither needs a Google
/// Maps key, which is why the flow keeps working while the map itself is
/// waiting for one.
class DevicePlaceLookup implements PlaceLookup {
  DevicePlaceLookup();

  static final shared = DevicePlaceLookup();

  /// geocoding 5 hands its work to an instance rather than to top-level
  /// functions, and building one per lookup would rebuild the platform
  /// channel each time.
  final geocoding.Geocoding _geocoder = geocoding.Geocoding();

  /// Long enough for a cold GPS fix indoors, short enough not to look hung.
  static const _fixTimeout = Duration(seconds: 15);

  /// Where the map opens when there is nothing better — the area ServiQ
  /// actually runs in, rather than the middle of the ocean that a zeroed
  /// coordinate would give.
  static const fallback = AddressDraft(
    latitude: 28.6350,
    longitude: 77.4350,
  );

  @override
  Future<Either<Failure, AddressDraft>> here() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Left(
          Failure(
            errorMessage:
                'Location is switched off. Turn it on, or drag the pin to '
                'where you are.',
            errorCode: 'LOCATION_SERVICE_OFF',
          ),
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const Left(
          Failure(
            errorMessage:
                'ServiQ has not been allowed to use your location. Drag the '
                'pin to where you are instead.',
            errorCode: 'LOCATION_DENIED',
          ),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: _fixTimeout,
        ),
      );
      return at(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      return Left(
        Failure(
          errorMessage: 'Could not find where you are. $e',
          errorCode: 'LOCATION_FAILED',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, AddressDraft>> at({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final places = await _geocoder.placemarkFromCoordinates(
        latitude,
        longitude,
      );
      if (places.isEmpty) {
        // A pin somewhere the geocoder has no name for is still a pin: the
        // coordinates are what a provider navigates to, so it is kept rather
        // than refused.
        return Right(
          AddressDraft(latitude: latitude, longitude: longitude),
        );
      }

      final place = places.first;
      return Right(
        AddressDraft(
          latitude: latitude,
          longitude: longitude,
          placeName: _nameOf(place),
          formattedAddress: formatPlacemark(place),
          pincode: place.postalCode?.trim() ?? '',
        ),
      );
    } catch (e) {
      return Left(
        Failure(
          errorMessage: 'Could not read the address off the map. $e',
          errorCode: 'GEOCODING_FAILED',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<AddressDraft>>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const Right([]);

    try {
      final locations = await _geocoder.locationFromAddress(trimmed);
      final drafts = <AddressDraft>[];
      // Named one at a time, because a coordinate is not something anybody
      // can choose between.
      for (final location in locations.take(6)) {
        final named = await at(
          latitude: location.latitude,
          longitude: location.longitude,
        );
        named.fold((_) {}, drafts.add);
      }
      return Right(drafts);
    } catch (e) {
      // The platform geocoder throws rather than returning nothing when it
      // cannot match, and "no results" is an answer, not a fault.
      return const Right([]);
    }
  }

  /// "Shakti Khand" — the most specific thing worth heading the sheet with.
  static String _nameOf(geocoding.Placemark place) {
    for (final candidate in [
      place.subLocality,
      place.locality,
      place.name,
      place.subAdministrativeArea,
    ]) {
      if (candidate != null && candidate.trim().isNotEmpty) {
        return candidate.trim();
      }
    }
    return 'Dropped pin';
  }

  /// The whole address on one line, with the blanks closed up.
  static String formatPlacemark(geocoding.Placemark place) => formatParts([
    place.name,
    place.street,
    place.subLocality,
    place.locality,
    place.subAdministrativeArea,
    place.administrativeArea,
    place.postalCode,
    place.country,
  ]);

  /// Joins the parts of an address, dropping the ones already said.
  ///
  /// The platform geocoder repeats itself heavily: on a real Ghaziabad fix it
  /// returned `name` "Sachin Home" and `street` "Sachin Home, Mahiuddin Pur
  /// Kanawni, Balaji Colony, Ghaziabad, Uttar Pradesh 201014, India" — every
  /// later field then appearing inside that street a second time. Comparing
  /// whole parts for equality does not catch that, so a part is dropped when
  /// it is *contained* in what has been said, and a longer part swallows the
  /// shorter ones it contains.
  ///
  /// Takes the strings rather than a Placemark so it can be checked without a
  /// device's geocoder behind it.
  static String formatParts(List<String?> candidates) {
    final said = <String>[];

    for (final candidate in candidates) {
      final part = candidate?.trim() ?? '';
      if (part.isEmpty) continue;
      final lower = part.toLowerCase();

      if (said.any((seen) => seen.toLowerCase().contains(lower))) continue;
      // This part says everything some earlier ones did, and more.
      said.removeWhere((seen) => lower.contains(seen.toLowerCase()));
      said.add(part);
    }

    return said.join(', ');
  }
}
