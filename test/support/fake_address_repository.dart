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

  /// What was sent to the endpoint, so a test can check the flow filled the
  /// fields in rather than only that it finished.
  final List<Map<String, Object?>> created = <Map<String, Object?>>[];

  /// Fails the save, for the error path on the details screen.
  Failure? failCreate;

  /// Fails the delete, for the row that could not be removed.
  Failure? failDelete;

  /// Fails setting the default.
  Failure? failSetDefault;

  /// The ids promoted, in order — a second entry for the same id is the bug
  /// this records, because the endpoint toggles.
  final List<int> promoted = <int>[];

  /// The patches sent, in order.
  final List<Map<String, Object?>> updates = <Map<String, Object?>>[];

  @override
  Future<Either<Failure, SavedAddress>> setDefault(int id) async {
    promoted.add(id);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failSetDefault != null) return Left(failSetDefault!);

    // The live endpoint toggles: asking for the current default again clears
    // it. The fake does the same, so a test can prove the app never asks.
    final current = _loaded.firstWhere(
      (address) => address.id == id,
      orElse: () => const SavedAddress(label: ''),
    );
    final becomes = !current.isDefault;

    _loaded = [
      for (final address in _loaded)
        if (address.id == id)
          address.copyWith(isDefault: becomes)
        else
          address.copyWith(isDefault: becomes ? false : address.isDefault),
    ];
    if (!_changes.isClosed) _changes.add(null);
    // And it answers `isDefault: true` either way, as the real one does —
    // which is why nothing may read this field to decide what to draw.
    return Right(
      _loaded.firstWhere((address) => address.id == id).copyWith(
        isDefault: true,
      ),
    );
  }

  @override
  Future<Either<Failure, SavedAddress>> update(
    int id, {
    String? label,
    String? line1,
    String? line2,
    String? landmark,
    String? pincode,
    double? latitude,
    double? longitude,
  }) async {
    updates.add({
      'id': id,
      'label': label,
      'line1': line1,
      'line2': line2,
      'landmark': landmark,
      'pincode': pincode,
      'lat': latitude,
      'lng': longitude,
    });
    if (delay > Duration.zero) await Future<void>.delayed(delay);

    // A merge, as the endpoint does it: what is left out keeps its value.
    final existing = _loaded.firstWhere((address) => address.id == id);
    final merged = existing.copyWith(
      label: label,
      line1: line1,
      line2: line2,
      landmark: landmark,
      pincode: pincode,
      lat: latitude,
      lng: longitude,
    );
    _loaded = [
      for (final address in _loaded)
        if (address.id == id) merged else address,
    ];
    if (!_changes.isClosed) _changes.add(null);
    return Right(merged);
  }

  /// The ids removed, in order.
  final List<int> deleted = <int>[];

  @override
  Future<Either<Failure, List<SavedAddress>>> delete(int id) async {
    deleted.add(id);
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failDelete != null) return Left(failDelete!);

    final removed = _loaded.firstWhere(
      (address) => address.id == id,
      orElse: () => const SavedAddress(label: ''),
    );
    var remaining = _loaded.where((address) => address.id != id).toList();
    // The server promotes another address when the default goes; the fake
    // does the same, because that is the behaviour the screen depends on.
    if (removed.isDefault && remaining.isNotEmpty) {
      remaining = [
        remaining.first.copyWith(isDefault: true),
        ...remaining.skip(1),
      ];
    }

    _loaded = remaining;
    _count = remaining.length;
    if (!_changes.isClosed) _changes.add(null);
    return Right(remaining);
  }

  @override
  Future<Either<Failure, SavedAddress>> create({
    required String label,
    required String line1,
    String? line2,
    String? landmark,
    String? localitySlug,
    String? pincode,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    created.add({
      'label': label,
      'line1': line1,
      'line2': line2,
      'landmark': landmark,
      'localitySlug': localitySlug,
      'pincode': pincode,
      'lat': latitude,
      'lng': longitude,
      'isDefault': isDefault,
    });
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failCreate != null) return Left(failCreate!);

    final saved = SavedAddress(
      id: 900 + created.length,
      label: label,
      line1: line1,
      line2: line2,
      landmark: landmark,
      localitySlug: localitySlug ?? '',
      localityName: localitySlug == null ? '' : 'Galleria Market 1',
      pincode: pincode ?? '',
      lat: latitude,
      lng: longitude,
      isDefault: isDefault,
    );
    _loaded = [..._loaded, saved];
    _count = _loaded.length;
    if (!_changes.isClosed) _changes.add(null);
    return Right(saved);
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
    // No fallback to the first: the endpoint decides which is the default,
    // and a list with none has none.
    return null;
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
