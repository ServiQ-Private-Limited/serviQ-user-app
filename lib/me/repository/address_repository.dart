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

  /// The address a booking will go to — the one the server marks default.
  ///
  /// Null whenever no address carries `isDefault`, which includes an account
  /// that has several. It used to fall back to the first in the list, and
  /// that was the app deciding something the endpoint had not said: a seeker
  /// with three addresses and no default saw the cart announce that the
  /// provider was coming to whichever one happened to be first.
  ///
  /// Null means the screens ask which one to use. It does not mean none are
  /// saved — [loaded] says that.
  SavedAddress? get defaultAddress {
    for (final address in _loaded) {
      if (address.isDefault) return address;
    }
    return null;
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

  /// Saves a new address.
  ///
  /// [localitySlug] is optional at the endpoint, and a slug the server does
  /// not know is refused outright with LOCALITY_NOT_FOUND — so a pin dropped
  /// outside the areas ServiQ runs in is saved without one rather than with
  /// a guess. The coordinates are kept either way, which is what a provider
  /// actually navigates to.
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
    try {
      final data = await apiClient.post(
        _path,
        data: {
          'label': label,
          'line1': line1,
          if (line2 != null && line2.isNotEmpty) 'line2': line2,
          if (landmark != null && landmark.isNotEmpty) 'landmark': landmark,
          if (localitySlug != null && localitySlug.isNotEmpty)
            'localitySlug': localitySlug,
          if (pincode != null && pincode.isNotEmpty) 'pincode': pincode,
          if (latitude != null) 'lat': latitude,
          if (longitude != null) 'lng': longitude,
          'isDefault': isDefault,
        },
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

      final response = ApiResponse.fromJson(data, SavedAddress.fromJson);
      final saved = response.responseData;
      if (!response.isSuccess || saved == null) {
        return Left(response.toFailure());
      }

      // The list the rest of the app reads is now out of date, so it is
      // refetched rather than patched: the server decides which address is
      // the default, and saving a new one can move it.
      await addresses();
      return Right(saved);
    } on DioException catch (e) {
      return Left(failureFromDioException(e));
    } catch (e) {
      return Left(Failure(errorMessage: e.toString()));
    }
  }

  /// Makes [id] the address every booking goes to.
  ///
  /// Two things about this endpoint are worth knowing, both established by
  /// calling it rather than from its shape:
  ///
  /// 1. It *toggles*. Asking it to make the current default the default again
  ///    clears it, leaving the account with none. Nothing in the app offers
  ///    that — "Set as default" is only drawn on rows that are not — and
  ///    [AddressesBloc] refuses the call as well, so it cannot be reached.
  /// 2. Its `responseData.isDefault` is **always true**, whichever way the
  ///    toggle actually went. So the answer is not trusted for that field:
  ///    the list is read back afterwards, and that is what the screen shows.
  ///    Believing the response would have drawn a DEFAULT pill on an address
  ///    the server had just un-defaulted.
  Future<Either<Failure, SavedAddress>> setDefault(int id) async {
    try {
      final data = await apiClient.put(
        '$_path/$id/default',
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

      final response = ApiResponse.fromJson(data, SavedAddress.fromJson);
      if (!response.isSuccess || response.responseData == null) {
        return Left(response.toFailure());
      }

      // The truth about which address is the default comes from the list,
      // not from what the call answered with.
      final reloaded = await addresses();
      return reloaded.fold(Left.new, (list) {
        final match = list.where((address) => address.id == id);
        return Right(match.isEmpty ? response.responseData! : match.first);
      });
    } on DioException catch (e) {
      return Left(failureFromDioException(e));
    } catch (e) {
      return Left(Failure(errorMessage: e.toString()));
    }
  }

  /// Changes an address in place.
  ///
  /// A partial update: whatever is left out keeps the value it had, and the
  /// address stays the default if it was one. Only the fields actually given
  /// are sent, so a form that does not ask about a landmark cannot erase it.
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
    return _one(
      () => apiClient.patch(
        '$_path/$id',
        data: {
          if (label != null) 'label': label,
          if (line1 != null) 'line1': line1,
          if (line2 != null) 'line2': line2,
          if (landmark != null) 'landmark': landmark,
          if (pincode != null) 'pincode': pincode,
          if (latitude != null) 'lat': latitude,
          if (longitude != null) 'lng': longitude,
        },
        options: Options(receiveTimeout: _timeout, sendTimeout: _timeout),
      ),
      onSaved: (saved) {
        _loaded = [
          for (final address in _loaded)
            if (address.id == saved.id) saved else address,
        ];
      },
    );
  }

  /// The shared shape of the two endpoints that answer with one address.
  Future<Either<Failure, SavedAddress>> _one(
    Future<dynamic> Function() call, {
    required void Function(SavedAddress saved) onSaved,
  }) async {
    try {
      final data = await call();

      if (data is! Map<String, dynamic>) {
        return const Left(
          Failure(
            errorMessage: 'Unexpected response from the server.',
            errorCode: 'MALFORMED_RESPONSE',
          ),
        );
      }

      final response = ApiResponse.fromJson(data, SavedAddress.fromJson);
      final saved = response.responseData;
      if (!response.isSuccess || saved == null) {
        return Left(response.toFailure());
      }

      onSaved(saved);
      _count = _loaded.length;
      _announce();
      return Right(saved);
    } on DioException catch (e) {
      return Left(failureFromDioException(e));
    } catch (e) {
      return Left(Failure(errorMessage: e.toString()));
    }
  }

  /// Removes an address.
  ///
  /// The endpoint answers with what is *left*, not with what went — and it
  /// promotes another address to default when the one deleted was it. So the
  /// list comes from the response rather than from dropping a row locally,
  /// which would have left the seeker with no default marked anywhere.
  Future<Either<Failure, List<SavedAddress>>> delete(int id) async {
    try {
      final data = await apiClient.delete(
        '$_path/$id',
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

      final remaining = [
        for (final entry in raw)
          if (entry is Map)
            SavedAddress.fromJson(Map<String, dynamic>.from(entry)),
      ];

      _loaded = remaining;
      _count = remaining.length;
      _announce();
      return Right(remaining);
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
