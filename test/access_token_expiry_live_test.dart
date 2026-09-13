import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_markerplace/login/model/auth_tokens.dart';
import 'package:local_markerplace/login/model/auth_user.dart';
import 'package:local_markerplace/login/repository/login_repository.dart';
import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/network/auth_session.dart';
import 'package:local_markerplace/network/token_refresh_interceptor.dart';
import 'package:local_markerplace/network/token_store.dart';

import 'support/fakes.dart';

/// Exercises the real 15-minute access-token expiry against the live backend.
///
/// Reads a session captured earlier (an access token that has since lapsed,
/// plus its still-valid refresh token) and drives a protected endpoint through
/// the app's own interceptor stack.
///
/// The fixture is SINGLE USE. Passing rotates the refresh token, so a second
/// run of the same file gets REFRESH_TOKEN_INVALID — that is the backend
/// working as designed, not a regression. To run it again, capture a fresh
/// session and let its access token age out:
///
///   1. POST /api/v1/auth/otp/request, then /verify, saving the response JSON
///   2. wait 900s for the access token to expire
///   3. run: SERVIQ_EXPIRED_SESSION=[that file] flutter test [this file]
void main() {
  const baseUrl = 'http://13.207.78.186:8080';
  final sessionFile = File(
    Platform.environment['SERVIQ_EXPIRED_SESSION'] ?? '',
  );

  // Needs a session whose access token has actually lapsed, which only the
  // harness can produce (sign in, wait out the 900s). Skipped rather than
  // failed when that fixture is absent, so the default suite stays green.
  final fixtureMissing = !sessionFile.existsSync();

  test(
    'an expired access token is renewed and the request replayed',
    () async {
      final captured =
          jsonDecode(sessionFile.readAsStringSync()) as Map<String, dynamic>;
      final tokensJson =
          (captured['responseData'] as Map<String, dynamic>)['tokens']
              as Map<String, dynamic>;
      final userJson =
          (captured['responseData'] as Map<String, dynamic>)['user']
              as Map<String, dynamic>;

      // Dio is built by hand rather than through appBuilder so the test owns the
      // client and can assert on what the interceptors did.
      final apiClient = APIClient(baseUrl: baseUrl);
      apiClient.dio.options.baseUrl = baseUrl;
      final repository = LoginRepository(apiClient: apiClient);
      final session = AuthSession(
        store: InMemoryTokenStore(),
        repository: repository,
        deviceIdentity: FakeDeviceIdentity('expiry-probe'),
      );
      apiClient.addInterceptor(AuthInterceptor(session));
      apiClient.addInterceptor(
        TokenRefreshInterceptor(session: session, dio: apiClient.dio),
      );

      final expired = AuthTokens(
        accessToken: tokensJson['accessToken'] as String,
        tokenType: tokensJson['tokenType'] as String,
        expiresIn: tokensJson['expiresIn'] as int,
        refreshToken: tokensJson['refreshToken'] as String,
        refreshExpiresIn: tokensJson['refreshExpiresIn'] as int,
        // Backdated past the 900s lifetime, matching the real elapsed time.
        issuedAt: DateTime.now().subtract(const Duration(seconds: 1000)),
      );
      await session.save(tokens: expired, user: AuthUser.fromJson(userJson));
      expect(session.needsRefresh, isTrue);

      // No validateStatus override: dio must throw on the 401 for the
      // interceptor's onError to run at all, which is how the app behaves.
      final response = await apiClient.dio.get('/api/v1/user/profile');

      // The call started with a dead token and still came back 200: the
      // interceptor refreshed and replayed it.
      expect(response.statusCode, 200);
      expect(response.data['responseData'], isNotNull);
      expect(
        session.tokens!.accessToken,
        isNot(expired.accessToken),
        reason: 'a new access token should now be held',
      );
      expect(
        session.tokens!.refreshToken,
        isNot(expired.refreshToken),
        reason: 'the refresh token rotates on every renewal',
      );
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
    skip: fixtureMissing
        ? 'set SERVIQ_EXPIRED_SESSION to a verify response whose access '
              'token has expired (see the access-token expiry test notes)'
        : null,
  );
}
