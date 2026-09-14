import 'package:dartz/dartz.dart';

import 'package:local_markerplace/me/model/address_draft.dart';
import 'package:local_markerplace/me/repository/place_lookup.dart';
import 'package:local_markerplace/network/failure.dart';

/// The device's location and geocoder, without a device.
class FakePlaceLookup implements PlaceLookup {
  FakePlaceLookup({
    this.current = const AddressDraft(
      latitude: 28.6412,
      longitude: 77.3910,
      placeName: 'Shakti Khand',
      formattedAddress:
          '766, Shakti Khand, Shakti Khand 4, Indirapuram, Ghaziabad, '
          'Uttar Pradesh 201014, India',
    ),
    this.hereFails,
    this.results = const [],
    this.delay = Duration.zero,
  });

  /// What `here()` answers, and what any pin resolves to.
  final AddressDraft current;

  /// Denied permission, location switched off — the seeker can still drag.
  final Failure? hereFails;

  final List<AddressDraft> results;
  final Duration delay;

  /// The coordinates looked up, in order.
  final List<(double, double)> resolved = <(double, double)>[];

  int hereCalls = 0;

  @override
  Future<Either<Failure, AddressDraft>> here() async {
    hereCalls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (hereFails != null) return Left(hereFails!);
    return Right(current);
  }

  @override
  Future<Either<Failure, AddressDraft>> at({
    required double latitude,
    required double longitude,
  }) async {
    resolved.add((latitude, longitude));
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return Right(
      current.copyWith(latitude: latitude, longitude: longitude),
    );
  }

  @override
  Future<Either<Failure, List<AddressDraft>>> search(String query) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    return Right(query.trim().isEmpty ? const [] : results);
  }
}
