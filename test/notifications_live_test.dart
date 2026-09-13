import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/login/repository/login_repository.dart';
import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/network/auth_session.dart';
import 'package:local_markerplace/network/token_store.dart';
import 'package:local_markerplace/notifications/repository/notification_repository.dart';

import 'support/fakes.dart';

/// The notifications endpoints against the real backend.
///
/// Tagged so it can be excluded: `flutter test --exclude-tags live`. Signs a
/// fresh number in each run, which means an account with no history — so
/// these assert the contract and the paging envelope rather than any
/// particular notification being there.
void main() {
  const baseUrl = 'http://13.207.78.186:8080';
  const deviceId = 'notif-probe';

  String uniqueNumber() {
    final tail = DateTime.now().microsecondsSinceEpoch % 1000000000;
    return '9${tail.toString().padLeft(9, '0')}';
  }

  Future<APIClient> signedInClient() async {
    final apiClient = APIClient(baseUrl: baseUrl);
    apiClient.dio.options.baseUrl = baseUrl;
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

    apiClient.addInterceptor(AuthInterceptor(session));
    return apiClient;
  }

  test(
    'a page comes back in the shape the drawer reads',
    () async {
      final repository = NotificationRepository(
        apiClient: await signedInClient(),
      );

      final result = await repository.notifications(page: 0, size: 5);

      result.fold((failure) => fail('expected a page, got: $failure'), (
        loaded,
      ) {
        expect(loaded.page, 0);
        // The size asked for is the size honoured, which is what paging rests
        // on — a server that ignored it would hand back its own default.
        expect(loaded.size, 5);
        expect(loaded.totalItems, greaterThanOrEqualTo(0));
        expect(loaded.items.length, lessThanOrEqualTo(5));
        expect(loaded.hasNext, isA<bool>());
      });
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'marking everything read is accepted and answers with a count',
    () async {
      final repository = NotificationRepository(
        apiClient: await signedInClient(),
      );

      final result = await repository.markAllRead();

      result.fold(
        (failure) => fail('expected the mark to be accepted, got: $failure'),
        (marked) => expect(marked, greaterThanOrEqualTo(0)),
      );
      // Whatever it marked, the badge is empty afterwards.
      expect(repository.unreadCount, 0);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'the list is the seeker own — it needs a token',
    () async {
      // Raw Dio rather than APIClient: the app's client is a singleton that
      // already carries the auth interceptor by now, so asking it would
      // prove nothing about an unsigned request.
      final dio = Dio(
        BaseOptions(baseUrl: baseUrl, validateStatus: (_) => true),
      );

      final response = await dio.get('/api/v1/user/notifications');

      expect(response.statusCode, 401);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
