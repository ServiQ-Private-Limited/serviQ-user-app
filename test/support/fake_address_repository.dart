import 'dart:async';

import 'package:dartz/dartz.dart';

import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';
import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/network/failure.dart';

/// The addresses endpoint without a server behind it.
class FakeAddressRepository implements AddressRepository {
  FakeAddressRepository({
    this.saved = const [],
    this.failFirst,
    this.delay = Duration.zero,
  });

  final List<SavedAddress> saved;

  /// Fails the first load once, then answers normally — which is what a
  /// retry has to be able to recover from.
  final Failure? failFirst;

  final Duration delay;

  /// How many times the list was asked for.
  int requested = 0;

  bool _firstHasFailed = false;

  @override
  Future<Either<Failure, List<SavedAddress>>> addresses() async {
    requested++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    if (failFirst != null && !_firstHasFailed) {
      _firstHasFailed = true;
      return Left(failFirst!);
    }

    _loaded = saved;
    _count = saved.length;
    if (!_changes.isClosed) _changes.add(null);
    return Right(saved);
  }

  @override
  Future<void> refreshCount() async {
    await addresses();
  }

  int? _count;

  @override
  int? get count => _count;

  @override
  List<SavedAddress> get loaded => _loaded;
  List<SavedAddress> _loaded = const [];

  @override
  SavedAddress? get defaultAddress {
    for (final address in _loaded) {
      if (address.isDefault) return address;
    }
    return _loaded.isEmpty ? null : _loaded.first;
  }

  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _changes.stream;

  @override
  APIClient get apiClient => throw UnimplementedError();
}

/// An address shaped the way the endpoint sends one.
SavedAddress sampleAddress({
  int id = 16,
  String label = 'Home',
  String line1 = 'Tower B, Flat 1204',
  String? line2,
  String? landmark,
  String localitySlug = 'galleria-market-1',
  String localityName = 'Galleria Market 1',
  String pincode = '201016',
  bool isDefault = false,
}) {
  return SavedAddress.fromJson({
    'id': id,
    'label': label,
    'line1': line1,
    'line2': line2,
    'landmark': landmark,
    'localitySlug': localitySlug,
    'localityName': localityName,
    'pincode': pincode,
    'lat': null,
    'lng': null,
    'isDefault': isDefault,
  });
}
