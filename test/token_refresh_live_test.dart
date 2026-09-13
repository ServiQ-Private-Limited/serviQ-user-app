import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/login/model/auth_tokens.dart';
import 'package:local_markerplace/login/repository/login_repository.dart';
import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/network/auth_session.dart';
import 'package:local_markerplace/network/token_refresh_interceptor.dart';
import 'package:local_markerplace/network/token_store.dart';

import 'support/fakes.dart';

/// The refresh endpoint against the real backend, end to end.
///
/// Tagged so it can be excluded: `flutter test --exclude-tags live`. Each run
/// signs a brand-new number in, because refreshing rotates the credential and
/// a spent one cannot be replayed.
void main() {
  const baseUrl = 'http://13.207.78.186:8080';
  const deviceId = 'dev-handset-01';

  /// A number nobody has used, so the run never trips the resend cooldown or
  /// inherits another run's session.
  String uniqueNumber() {
    final tail = DateTime.now().microsecondsSinceEpoch % 1000000000;
    return '9${tail.toString().padLeft(9, '0')}';
  }

  /// Signs in for real and hands back the session the app would hold.
  Future<AuthSession> signIn(APIClient apiClient) async {
    final repository = LoginRepository(apiClient: apiClient);
    final session = AuthSession(
      store: InMemoryTokenStore(),
      repository: repository,
      deviceIdentity: FakeDeviceIdentity(deviceId),
    );

    final phoneNumber = uniqueNumber();
    final requested = await repository.requestOtp(
      countryCode: '+91',
      phoneNumber: phoneNumber,
    );
    final otp = requested.fold(
      (failure) => fail('could not request an OTP: $failure'),
      (result) => result.devOtp,
    );
    // The backend runs its `log` OTP provider here, which echoes the code
    // back instead of sending it. Without that there is nothing to verify.
    expect(otp, isNotNull, reason: 'the dev OTP provider should echo the code');

    final verified = await repository.verifyOtp(
      countryCode: '+91',
      phoneNumber: phoneNumber,
      otp: otp!,
      deviceId: deviceId,
    );
    await verified.fold(
      (failure) async => fail('could not verify the OTP: $failure'),
      (result) => session.save(tokens: result.tokens, user: result.user),
    );

    return session;
  }

  test(
    'a refresh returns a live pair and rotates the credential',
    () async {
      final apiClient = APIClient(baseUrl: baseUrl);
      apiClient.dio.options.baseUrl = baseUrl;
      final session = await signIn(apiClient);

      final before = session.tokens!;
      expect(before.tokenType, 'Bearer');
      expect(before.expiresIn, 900);
      expect(before.refreshExpiresIn, 7776000);

      expect(await session.refreshIfNeeded(), isTrue);

      final after = session.tokens!;
      // The backend rotates on every call — the token sent is now spent.
      expect(after.refreshToken, isNot(before.refreshToken));
      expect(after.accessToken, isNotEmpty);
      expect(after.expiresIn, 900);
      expect(after.isAccessTokenExpired, isFalse);
      // Deliberately no assertion that the access token *string* changed. Its
      // claims carry `iat` to the second and the signature is deterministic,
      // so refreshing inside the same second hands back a byte-identical
      // token — the same live session, not a stale one.
      expect(after.issuedAt.isAfter(before.issuedAt), isTrue);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'the refreshed access token opens a protected endpoint',
    () async {
      final apiClient = APIClient(baseUrl: baseUrl);
      apiClient.dio.options.baseUrl = baseUrl;
      final session = await signIn(apiClient);
      apiClient.addInterceptor(AuthInterceptor(session));
      apiClient.addInterceptor(
        TokenRefreshInterceptor(session: session, dio: apiClient.dio),
      );

      expect(await session.refreshIfNeeded(), isTrue);

      // Signed with the token the refresh just minted, through the app's own
      // interceptor stack.
      final response = await apiClient.dio.get('/api/v1/user/profile');
      expect(response.statusCode, 200);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'replaying a spent refresh token ends the session',
    () async {
      final apiClient = APIClient(baseUrl: baseUrl);
      apiClient.dio.options.baseUrl = baseUrl;
      final repository = LoginRepository(apiClient: apiClient);
      final session = await signIn(apiClient);

      final spent = session.tokens!.refreshToken;
      expect(await session.refreshIfNeeded(), isTrue);

      // The backend treats a replayed token as theft and retires the whole
      // session. This is why AuthSession refuses to run two refreshes at once.
      final replay = await repository.refreshTokens(
        refreshToken: spent,
        deviceId: deviceId,
      );
      replay.fold(
        (failure) => expect(failure.errorCode, 'REFRESH_TOKEN_REUSED'),
        (_) => fail('a spent refresh token should not be accepted'),
      );
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a rejected refresh clears the session rather than keeping it',
    () async {
      final apiClient = APIClient(baseUrl: baseUrl);
      apiClient.dio.options.baseUrl = baseUrl;
      final session = await signIn(apiClient);

      final spent = session.tokens!.refreshToken;
      expect(await session.refreshIfNeeded(), isTrue);

      // Put the spent token back and refresh again: the server rejects it, and
      // a rejection — unlike a dropped connection — must sign the user out.
      final live = session.tokens!;
      await session.save(
        tokens: AuthTokens(
          accessToken: live.accessToken,
          tokenType: live.tokenType,
          expiresIn: live.expiresIn,
          refreshToken: spent,
          refreshExpiresIn: live.refreshExpiresIn,
        ),
        user: session.user!,
      );
      expect(await session.refreshIfNeeded(), isFalse);
      expect(session.isAuthenticated, isFalse);
      expect(session.tokens, isNull);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
