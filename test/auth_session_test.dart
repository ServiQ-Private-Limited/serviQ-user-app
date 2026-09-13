import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:local_markerplace/network/auth_session.dart';
import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/network/token_store.dart';

import 'support/fakes.dart';

void main() {
  group('bootstrap', () {
    test('no stored token sends the user to login', () async {
      final session = AuthSession(
        store: FakePersistentStore(),
        repository: FakeLoginRepository(),
        deviceIdentity: FakeDeviceIdentity(),
      );

      expect(await session.bootstrap(), AuthBootstrapResult.noSession);
      expect(session.isAuthenticated, isFalse);
    });

    test('a stored token is exchanged and the user lands signed in', () async {
      final store = FakePersistentStore();
      await store.write(
        StoredCredentials(refreshToken: 'stored-refresh', user: testUser),
      );
      final repository = FakeLoginRepository(
        responses: [
          testTokens(accessToken: 'fresh-access', refreshToken: 'rotated'),
        ],
      );

      final session = AuthSession(
        store: store,
        repository: repository,
        deviceIdentity: FakeDeviceIdentity(),
      );

      expect(await session.bootstrap(), AuthBootstrapResult.signedIn);
      expect(repository.refreshCalls, ['stored-refresh']);
      expect(session.tokens?.accessToken, 'fresh-access');
      expect(session.user?.userId, 'USRJIY7QTUF');
    });

    test('a rejected token is cleared and lands on login', () async {
      final store = FakePersistentStore();
      await store.write(
        StoredCredentials(refreshToken: 'revoked', user: testUser),
      );
      final session = AuthSession(
        store: store,
        deviceIdentity: FakeDeviceIdentity(),
        repository: FakeLoginRepository(
          failure: const Failure(
            errorMessage: 'This session has been ended for security reasons.',
            errorCode: 'REFRESH_TOKEN_REUSED',
          ),
        ),
      );

      expect(await session.bootstrap(), AuthBootstrapResult.rejected);
      expect(session.isAuthenticated, isFalse);
      expect(store.blob, isNull, reason: 'a dead token must not be kept');
    });
  });

  group('rotation', () {
    test('the rotated token replaces the stored one', () async {
      final store = FakePersistentStore();
      await store.write(
        StoredCredentials(refreshToken: 'first', user: testUser),
      );
      final session = AuthSession(
        store: store,
        deviceIdentity: FakeDeviceIdentity(),
        repository: FakeLoginRepository(
          responses: [testTokens(refreshToken: 'second')],
        ),
      );

      await session.bootstrap();

      // The spent token must be gone from disk: replaying it would trip the
      // backend's reuse detection and end the session.
      final persisted = await store.read();
      expect(persisted?.refreshToken, 'second');
    });

    test('the access token is never written to storage', () async {
      final store = FakePersistentStore();
      final session = AuthSession(
        store: store,
        repository: FakeLoginRepository(),
        deviceIdentity: FakeDeviceIdentity(),
      );

      await session.save(
        tokens: testTokens(accessToken: 'super-secret-access'),
        user: testUser,
      );

      expect(store.blob, isNot(contains('super-secret-access')));
      expect(store.blob, contains('refresh-token'));
    });

    test('concurrent refreshes share one call to the server', () async {
      final store = FakePersistentStore();
      await store.write(
        StoredCredentials(refreshToken: 'first', user: testUser),
      );
      final repository = FakeLoginRepository(
        responses: [testTokens(refreshToken: 'second')],
      );
      final session = AuthSession(
        store: store,
        repository: repository,
        deviceIdentity: FakeDeviceIdentity(),
      );
      await session.bootstrap();

      // Hold the next refresh open so both callers are genuinely in flight.
      final gate = Completer<void>();
      repository.gate = gate.future;
      final first = session.refreshIfNeeded();
      final second = session.refreshIfNeeded();
      gate.complete();
      await Future.wait([first, second]);

      // Two calls would have presented the same token twice and ended the
      // session for reuse.
      expect(
        repository.refreshCalls.length,
        2,
        reason: '1 bootstrap + 1 shared',
      );
    });
  });

  test('signing out clears memory and storage', () async {
    final store = FakePersistentStore();
    final session = AuthSession(
      store: store,
      repository: FakeLoginRepository(),
      deviceIdentity: FakeDeviceIdentity(),
    );
    await session.save(tokens: testTokens(), user: testUser);

    await session.clear();

    expect(session.isAuthenticated, isFalse);
    expect(session.user, isNull);
    expect(store.blob, isNull);
  });

  group('offline launch', () {
    test('a network failure keeps the stored token', () async {
      final store = FakePersistentStore();
      await store.write(
        StoredCredentials(refreshToken: 'still-good', user: testUser),
      );
      final session = AuthSession(
        store: store,
        deviceIdentity: FakeDeviceIdentity(),
        repository: FakeLoginRepository(
          failure: const Failure(
            errorMessage: 'No internet connection. Please check your network.',
            errorCode: 'CONNECTION_ERROR',
          ),
        ),
      );

      expect(await session.bootstrap(), AuthBootstrapResult.offline);
      // The whole point: a moment without signal must not sign the user out.
      final kept = await store.read();
      expect(kept?.refreshToken, 'still-good');
    });

    test('the session comes back once the network does', () async {
      final store = FakePersistentStore();
      await store.write(
        StoredCredentials(refreshToken: 'still-good', user: testUser),
      );
      // First launch: offline, token survives.
      await AuthSession(
        store: store,
        deviceIdentity: FakeDeviceIdentity(),
        repository: FakeLoginRepository(
          failure: const Failure(errorCode: 'CONNECTION_ERROR'),
        ),
      ).bootstrap();

      // Second launch, network restored.
      final online = AuthSession(
        store: store,
        deviceIdentity: FakeDeviceIdentity(),
        repository: FakeLoginRepository(
          responses: [testTokens(refreshToken: 'rotated')],
        ),
      );

      expect(await online.bootstrap(), AuthBootstrapResult.signedIn);
      expect(online.isAuthenticated, isTrue);
    });

    test('a timeout also keeps the token', () async {
      final store = FakePersistentStore();
      await store.write(
        StoredCredentials(refreshToken: 'still-good', user: testUser),
      );
      final session = AuthSession(
        store: store,
        deviceIdentity: FakeDeviceIdentity(),
        repository: FakeLoginRepository(
          failure: const Failure(errorCode: 'TIMEOUT'),
        ),
      );

      expect(await session.bootstrap(), AuthBootstrapResult.offline);
      expect(store.blob, isNotNull);
    });

    test('a request can revive a session the launch could not', () async {
      final store = FakePersistentStore();
      await store.write(
        StoredCredentials(refreshToken: 'still-good', user: testUser),
      );

      // Launched with no signal: the token survives, but nothing is held in
      // memory to sign a request with.
      final repository = FakeLoginRepository(
        failure: const Failure(errorCode: 'CONNECTION_ERROR'),
      );
      final session = AuthSession(
        store: store,
        deviceIdentity: FakeDeviceIdentity(),
        repository: repository,
      );
      expect(await session.bootstrap(), AuthBootstrapResult.offline);
      expect(session.isAuthenticated, isFalse);
      expect(session.hasStoredCredential, isTrue);

      // The network comes back while the app is still open. Without this the
      // seeker would have to restart before anything worked again.
      repository.failure = null;
      repository.responses = [testTokens(refreshToken: 'rotated')];

      expect(await session.refreshIfNeeded(), isTrue);
      expect(session.isAuthenticated, isTrue);
      expect((await store.read())?.refreshToken, 'rotated');
    });

    test('a real rejection still clears the token', () async {
      final store = FakePersistentStore();
      await store.write(
        StoredCredentials(refreshToken: 'revoked', user: testUser),
      );
      final session = AuthSession(
        store: store,
        deviceIdentity: FakeDeviceIdentity(),
        repository: FakeLoginRepository(
          failure: const Failure(errorCode: 'REFRESH_TOKEN_REUSED'),
        ),
      );

      expect(await session.bootstrap(), AuthBootstrapResult.rejected);
      expect(store.blob, isNull);
    });
  });
}
