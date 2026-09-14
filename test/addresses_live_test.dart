import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/login/repository/login_repository.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';
import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/network/auth_session.dart';
import 'package:local_markerplace/network/token_store.dart';

import 'support/fakes.dart';

/// The addresses endpoint against the real backend.
///
/// Tagged so it can be excluded: `flutter test --exclude-tags live`. Signs a
/// fresh number in each run, which means an account with nothing saved — so
/// this asserts the contract and the empty answer rather than any particular
/// address being there.
void main() {
  const baseUrl = 'http://13.207.78.186:8080';
  const deviceId = 'address-probe';

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
    'an account with nothing saved answers with an empty list, not an error',
    () async {
      final repository = AddressRepository(apiClient: await signedInClient());

      final result = await repository.addresses();

      result.fold(
        (failure) => fail('expected a list, got: $failure'),
        (addresses) => expect(addresses, isEmpty),
      );
      // Counted, and known to be none — which is what lets the Me row say so.
      expect(repository.count, 0);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'an address saved comes back in the shape the screen reads',
    () async {
      final apiClient = await signedInClient();
      final repository = AddressRepository(apiClient: apiClient);

      await apiClient.post(
        '/api/v1/user/addresses',
        data: const {
          'label': 'Home',
          'line1': 'Tower B, Flat 1204',
          'line2': 'Sector 4',
          'landmark': 'Opposite the community hall',
          'localitySlug': 'galleria-market-1',
          'pincode': '201016',
          'isDefault': true,
        },
      );

      final result = await repository.addresses();

      result.fold((failure) => fail('expected a list, got: $failure'), (
        addresses,
      ) {
        expect(addresses, hasLength(1));
        final saved = addresses.single;
        expect(saved.id, isNotNull);
        expect(saved.label, 'Home');
        expect(saved.isDefault, isTrue);
        // The slug is what home and search match on; the name is what the
        // seeker reads. The server fills the name in from the slug.
        expect(saved.localitySlug, 'galleria-market-1');
        expect(saved.localityName, 'Galleria Market 1');
        expect(
          saved.street,
          'Tower B, Flat 1204, Sector 4, Opposite the community hall',
        );
        expect(saved.area, 'Galleria Market 1, 201016');
      });
      expect(repository.count, 1);
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

      final response = await dio.get('/api/v1/user/addresses');

      expect(response.statusCode, 401);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
