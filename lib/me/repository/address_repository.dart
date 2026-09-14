import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/network/api_response.dart';
import 'package:local_markerplace/network/failure.dart';

/// The seeker's saved addresses, from the server.
///
/// The endpoint is the seeker's own, so the call goes out signed — unsigned
/// it answers 401 rather than somebody else's addresses.
class AddressRepository {
  AddressRepository({required this.apiClient});

  /// The one the Me tab counts from and the addresses screen reads, so a list
  /// loaded on one is reflected by the other.
  ///
  /// [APIClient] is a singleton keyed on its first construction, so this
  /// picks up the configured client rather than making a second one.
  static final AddressRepository shared = AddressRepository(
    apiClient: APIClient(baseUrl: ''),
  );

  final APIClient apiClient;

  static const _path = '/api/v1/user/addresses';

  /// How long the screen waits before calling it a failure. The client's
  /// default is two minutes, which for a screen somebody is looking at is a
  /// hang rather than a wait.
  static const _timeout = Duration(seconds: 10);

  /// Announced when the list is loaded, so the Me row that counts addresses
  /// is told rather than sitting on the figure it was built with.
  Stream<void> get changes => _changes.stream;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// How many the last load saw, for the Me tab's "N saved".
  ///
  /// Null until something has actually been loaded — which is what lets the
  /// row stay quiet rather than claim zero for a seeker whose addresses have
  /// simply not been fetched yet.
  int? get count => _count;
  int? _count;

  /// What the last load returned, kept so the screens that *use* an address
  /// — confirming a visit, the receipt, the cart — can read the seeker's own
  /// rather than each carrying a written-in one.
  List<SavedAddress> get loaded => List.unmodifiable(_loaded);
  List<SavedAddress> _loaded = const [];

  /// The address a booking will go to.
  ///
  /// Null when nothing has been loaded, and also when the seeker has saved
  /// nothing — both of which mean the screens have no address to show, which
  /// is a thing to say rather than a blank to fill with an invented one.
  SavedAddress? get defaultAddress {
    for (final address in _loaded) {
      if (address.isDefault) return address;
    }
    // No address is marked default but some exist: the first is the one a
    // booking would use, so it is the one to show.
    return _loaded.isEmpty ? null : _loaded.first;
  }

  Future<Either<Failure, List<SavedAddress>>> addresses() async {
    try {
      final data = await apiClient.get(
        _path,
        options: Options(receiveTimeout: _timeout, sendTimeout: _timeout),
      );

      if (data is! Map<String, dynamic>) {
        return const Left(
          Failure(
            errorMessage: 'Unexpected response from the server.',
            errorCode: 'MALFORMED_RESPONSE',
          ),
        );
      }

      // responseData is a bare array here, not the object [ApiResponse] parses
      // into — so the envelope is read for the verdict and the list is taken
      // off the body itself.
      final response = ApiResponse.fromJson(data, (json) => json);
      if (!response.isSuccess) return Left(response.toFailure());

      final raw = data['responseData'];
      if (raw is! List) {
        return const Left(
          Failure(
            errorMessage: 'Unexpected response from the server.',
            errorCode: 'MALFORMED_RESPONSE',
          ),
        );
      }

      final addresses = [
        for (final entry in raw)
          if (entry is Map)
            SavedAddress.fromJson(Map<String, dynamic>.from(entry)),
      ];
      _loaded = addresses;
      _count = addresses.length;
      _announce();
      return Right(addresses);
    } on DioException catch (e) {
      return Left(failureFromDioException(e));
    } catch (e) {
      return Left(Failure(errorMessage: e.toString()));
    }
  }

  /// Loads the list for the count alone, without the screen open.
  ///
  /// Failures are swallowed: a row that cannot count is a row without a
  /// figure, not an error worth putting in front of somebody on the Me tab.
  Future<void> refreshCount() async {
    await addresses();
  }

  void _announce() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
