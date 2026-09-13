import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../core/device_identity.dart';
import '../login/model/auth_tokens.dart';
import '../login/model/auth_user.dart';
import '../login/repository/login_repository.dart';
import 'failure.dart';
import 'token_store.dart';

/// Outcome of the launch-time bootstrap, which decides the first screen.
enum AuthBootstrapResult {
  /// No refresh token was stored — a first launch, or after signing out.
  noSession,

  /// A stored token was exchanged for a live one; go straight to the dashboard.
  signedIn,

  /// The stored token was rejected. It has been cleared; show the login screen.
  rejected,

  /// The server could not be reached. The token is untouched, so a later
  /// launch with a working connection signs the user back in.
  offline,
}

/// The endpoints that mint or renew a session.
///
/// They must never trigger a refresh, in either interceptor: the refresh call
/// itself goes out through this same client, so refreshing before one would
/// recurse, and retrying `/token/refresh` on its own 401 would loop. Shared by
/// [AuthInterceptor] and TokenRefreshInterceptor so the two lists cannot drift
/// apart.
const authEndpointPaths = {
  '/api/v1/auth/otp/request',
  '/api/v1/auth/otp/verify',
  '/api/v1/auth/token/refresh',
  // Both logout endpoints carry the refresh token in their body. Refreshing
  // first would rotate that token and leave the request revoking one the
  // server has already retired, so they have to be left alone too.
  '/api/v1/auth/logout',
  '/api/v1/auth/logout-all',
};

/// Error codes that mean the transport failed rather than the credential
/// being refused. Clearing a refresh token on one of these would sign a user
/// out for good because of a moment without signal.
const _transportErrorCodes = {'TIMEOUT', 'CONNECTION_ERROR', 'NETWORK_ERROR'};

/// The app's single source of truth for who is signed in.
///
/// Holds the access token in memory only and persists the refresh token, so a
/// returning user is signed back in by refreshing rather than by restoring a
/// stale access token.
class AuthSession {
  final TokenStore store;
  final LoginRepository repository;
  final DeviceIdentity deviceIdentity;

  AuthSession({
    required this.store,
    required this.repository,
    required this.deviceIdentity,
  });

  AuthTokens? _tokens;
  AuthUser? _user;

  /// Guards against two refreshes running at once. The backend ends the
  /// session if a refresh token is presented twice, so a concurrent pair would
  /// sign the user out rather than merely racing.
  Future<bool>? _inFlightRefresh;

  AuthTokens? get tokens => _tokens;
  AuthUser? get user => _user;

  bool get isAuthenticated => _tokens != null;

  /// A refresh token survived a launch that could not spend it — the network
  /// was down rather than the credential being refused.
  ///
  /// The session is not signed in, but it is not signed out either: it is
  /// one successful refresh away, which is what [refreshIfNeeded] will try
  /// the next time anything asks for the network.
  bool get hasStoredCredential => _storedRefreshToken != null;

  String? _storedRefreshToken;

  bool get needsRefresh => _tokens?.isAccessTokenExpired ?? false;

  /// Runs the launch lifecycle: read the stored refresh token, and if there is
  /// one, exchange it for a live session before the first route is chosen.
  Future<AuthBootstrapResult> bootstrap() async {
    final stored = await store.read();
    if (stored == null) return AuthBootstrapResult.noSession;

    _user = stored.user;
    _storedRefreshToken = stored.refreshToken;
    if (await _refresh(stored.refreshToken)) {
      return AuthBootstrapResult.signedIn;
    }
    // A token that survived the attempt was never rejected — the network was
    // simply unavailable.
    return _lastRefreshWasTransportFailure
        ? AuthBootstrapResult.offline
        : AuthBootstrapResult.rejected;
  }

  bool _lastRefreshWasTransportFailure = false;

  /// Renews the access token, reusing an in-flight attempt if one is already
  /// running. Returns false when the session is gone, in which case it has
  /// already been cleared.
  Future<bool> refreshIfNeeded() {
    final existing = _inFlightRefresh;
    if (existing != null) return existing;

    // Falls back to the token on disk, so a session the launch could not
    // revive because the network was down comes back on the first request
    // that succeeds — rather than the seeker having to restart the app.
    final refreshToken = _tokens?.refreshToken ?? _storedRefreshToken;
    if (refreshToken == null) return Future.value(false);
    return _refresh(refreshToken);
  }

  Future<bool> _refresh(String refreshToken) {
    final existing = _inFlightRefresh;
    if (existing != null) return existing;

    final attempt = _performRefresh(refreshToken);
    _inFlightRefresh = attempt;
    // Cleared however the attempt ends, so a failure cannot leave every later
    // refresh waiting on a dead future.
    return attempt.whenComplete(() => _inFlightRefresh = null);
  }

  Future<bool> _performRefresh(String refreshToken) async {
    final result = await repository.refreshTokens(
      refreshToken: refreshToken,
      deviceId: deviceIdentity.deviceId,
    );

    return result.fold(
      (failure) async {
        final isTransport = _transportErrorCodes.contains(failure.errorCode);
        _lastRefreshWasTransportFailure = isTransport;
        // Only a genuine rejection retires the credential. Wiping it because
        // the network was down would turn a moment without signal into a
        // permanent sign-out.
        if (!isTransport) await clear();
        return false;
      },
      (tokens) async {
        _lastRefreshWasTransportFailure = false;
        _tokens = tokens;
        _storedRefreshToken = tokens.refreshToken;
        // The server has already rotated the token, so the old one is spent.
        // Persist the replacement before anything can use it — a crash between
        // these two lines would otherwise leave a token on disk that the next
        // launch would be locked out by.
        await store.write(
          StoredCredentials(refreshToken: tokens.refreshToken, user: _user),
        );
        return true;
      },
    );
  }

  /// Called after OTP verification, the one point where a user arrives too.
  Future<void> save({
    required AuthTokens tokens,
    required AuthUser user,
  }) async {
    _tokens = tokens;
    _user = user;
    await store.write(
      StoredCredentials(refreshToken: tokens.refreshToken, user: user),
    );
  }

  /// Ends the session: asks the backend to retire the refresh token, then
  /// clears this device regardless of how that went.
  ///
  /// The local clear is deliberately unconditional. Someone who taps "Log out"
  /// has to end up logged out even with no signal; leaving them signed in
  /// because the call failed would be the worse outcome, and the server-side
  /// row expires on its own. The [Failure] is still returned so the UI can say
  /// the server was not reached.
  Future<Either<Failure, Unit>> signOut() async {
    final refreshToken = _tokens?.refreshToken;
    final result = refreshToken == null
        ? const Right<Failure, Unit>(unit)
        : await repository.logout(refreshToken: refreshToken);
    await clear();
    return result;
  }

  /// The same, for every device the account is signed in on.
  ///
  /// Answers with how many sessions the server retired so the UI can say what
  /// happened. A device holding no token has nothing to revoke and reports
  /// zero rather than calling out to say so.
  Future<Either<Failure, int>> signOutEverywhere() async {
    final refreshToken = _tokens?.refreshToken;
    final result = refreshToken == null
        ? const Right<Failure, int>(0)
        : await repository.logoutAll(refreshToken: refreshToken);
    await clear();
    return result;
  }

  Future<void> clear() async {
    _tokens = null;
    _user = null;
    _storedRefreshToken = null;
    await store.clear();
  }
}

/// Attaches the bearer token to every outgoing request once the user is signed
/// in. Requests made before verification simply go out unauthenticated, which
/// is what the OTP endpoints themselves need.
///
/// Also renews a token that has already lapsed, before the request leaves.
/// The access token lives 15 minutes, so any app left open longer than that
/// would otherwise spend a round trip discovering what it could already tell
/// from [AuthSession.needsRefresh]. TokenRefreshInterceptor still handles the
/// other case — a token this side believes is live that the server rejects.
class AuthInterceptor extends Interceptor {
  final AuthSession session;

  AuthInterceptor(this.session);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final isAuthEndpoint = authEndpointPaths.contains(options.path);
    // A session that could not be revived at launch — the app opened with no
    // signal — is revived here instead, on the first request made once there
    // is a network again.
    final needsReviving =
        !session.isAuthenticated && session.hasStoredCredential;
    if (!isAuthEndpoint && (session.needsRefresh || needsReviving)) {
      // Single-flight inside AuthSession, so several requests waking together
      // after expiry share one refresh rather than racing to spend the token.
      await session.refreshIfNeeded();
    }
    final tokens = session.tokens;
    if (tokens != null && tokens.accessToken.isNotEmpty) {
      options.headers['Authorization'] = tokens.authorizationHeader;
    }
    handler.next(options);
  }
}
