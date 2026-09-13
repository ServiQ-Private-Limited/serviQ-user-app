import 'package:dartz/dartz.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_markerplace/login/model/auth_tokens.dart';
import 'package:local_markerplace/login/model/auth_user.dart';
import 'package:local_markerplace/login/model/otp_request_result.dart';
import 'package:local_markerplace/login/model/verify_otp_result.dart';
import 'package:local_markerplace/login/repository/login_repository.dart';
import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/core/device_identity.dart';
import 'package:local_markerplace/network/token_store.dart';

const testUser = AuthUser(
  userId: 'USRJIY7QTUF',
  username: '9876567898',
  countryCode: '+91',
  phoneNumber: '9876567898',
  role: 'USER',
  verified: true,
);

AuthTokens testTokens({
  String accessToken = 'access-token',
  String refreshToken = 'refresh-token',
  int expiresIn = 900,
  int refreshExpiresIn = 7776000,
  DateTime? issuedAt,
}) {
  return AuthTokens(
    accessToken: accessToken,
    tokenType: 'Bearer',
    expiresIn: expiresIn,
    refreshToken: refreshToken,
    refreshExpiresIn: refreshExpiresIn,
    issuedAt: issuedAt,
  );
}

/// Stands in for real secure storage: the blob outlives the AuthSession that
/// wrote it, which is what a restart looks like.
class FakePersistentStore implements TokenStore {
  String? blob;

  FakePersistentStore({this.blob});

  @override
  Future<StoredCredentials?> read() async =>
      blob == null ? null : StoredCredentials.decode(blob!);

  @override
  Future<void> write(StoredCredentials credentials) async =>
      blob = credentials.encode();

  @override
  Future<void> clear() async => blob = null;
}

/// A LoginRepository whose refresh endpoint is scripted, recording the tokens
/// it was called with so rotation can be checked.
class FakeLoginRepository implements LoginRepository {
  final List<String> refreshCalls = [];
  final List<String> refreshDeviceIds = [];

  /// Refresh tokens the logout endpoint was asked to retire.
  final List<String> logoutCalls = [];

  /// When set, logout comes back Left — the server unreachable, say.
  Failure? logoutFailure;

  /// Refresh tokens the all-devices endpoint was asked to retire.
  final List<String> logoutAllCalls = [];

  /// How many sessions the all-devices endpoint reports revoking.
  int revokedSessions = 1;

  /// When set, the all-devices logout comes back Left.
  Failure? logoutAllFailure;

  /// Tokens handed back on success, in order.
  ///
  /// Mutable, so a test can script a repository that fails while the network
  /// is down and then answers when it comes back.
  List<AuthTokens> responses;
  Failure? failure;

  /// Awaited before each refresh returns, letting a test hold two calls in
  /// flight at once.
  Future<void>? gate;

  FakeLoginRepository({this.responses = const [], this.failure});

  int _answered = 0;

  @override
  Future<Either<Failure, AuthTokens>> refreshTokens({
    required String refreshToken,
    required String deviceId,
  }) async {
    refreshCalls.add(refreshToken);
    refreshDeviceIds.add(deviceId);
    final pending = gate;
    if (pending != null) await pending;
    if (failure != null) return Left(failure!);
    // Counted separately from the calls, so a failed attempt does not eat a
    // scripted success.
    if (_answered >= responses.length) {
      return const Left(Failure(errorMessage: 'no scripted response'));
    }
    return Right(responses[_answered++]);
  }

  @override
  Future<Either<Failure, Unit>> logout({required String refreshToken}) async {
    logoutCalls.add(refreshToken);
    final failure = logoutFailure;
    return failure == null ? const Right(unit) : Left(failure);
  }

  @override
  Future<Either<Failure, int>> logoutAll({required String refreshToken}) async {
    logoutAllCalls.add(refreshToken);
    final failure = logoutAllFailure;
    return failure == null ? Right(revokedSessions) : Left(failure);
  }

  @override
  APIClient get apiClient => throw UnimplementedError();

  @override
  Future<Either<Failure, OtpRequestResult>> requestOtp({
    required String countryCode,
    required String phoneNumber,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, VerifyOtpResult>> verifyOtp({
    required String countryCode,
    required String phoneNumber,
    required String otp,
    required String deviceId,
  }) => throw UnimplementedError();
}

/// A DeviceIdentity that is already loaded, so tests never touch the platform
/// keystore.
class FakeDeviceIdentity implements DeviceIdentity {
  FakeDeviceIdentity([this._id = 'test-device']);

  final String _id;

  @override
  String get deviceId => _id;

  @override
  Future<String> load() async => _id;

  @override
  FlutterSecureStorage get storage => throw UnimplementedError();
}
