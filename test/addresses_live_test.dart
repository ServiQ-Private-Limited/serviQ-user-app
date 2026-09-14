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
    'an address is added with everything the form collects',
    () async {
      final repository = AddressRepository(apiClient: await signedInClient());

      final result = await repository.create(
        label: 'Home',
        line1: 'A-101, Ajnara Gen X',
        landmark: 'Opposite the clubhouse',
        localitySlug: 'galleria-market-1',
        pincode: '201016',
        latitude: 28.6412,
        longitude: 77.3910,
      );

      result.fold((failure) => fail('expected it to save, got: $failure'), (
        saved,
      ) {
        expect(saved.id, isNotNull);
        expect(saved.label, 'Home');
        expect(saved.line1, 'A-101, Ajnara Gen X');
        expect(saved.landmark, 'Opposite the clubhouse');
        expect(saved.localityName, 'Galleria Market 1');
        expect(saved.pincode, '201016');
        expect(saved.lat, 28.6412);
        // The first address an account has is the one every booking uses.
        expect(saved.isDefault, isTrue);
      });
      expect(repository.count, 1);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a locality the server does not know is refused, not guessed at',
    () async {
      final repository = AddressRepository(apiClient: await signedInClient());

      final result = await repository.create(
        label: 'Elsewhere',
        line1: 'A-1',
        localitySlug: 'shakti-khand-4',
      );

      result.fold(
        (failure) => expect(failure.errorCode, 'LOCALITY_NOT_FOUND'),
        (saved) => fail('expected a refusal, got $saved'),
      );
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'deleting answers with what is left, and promotes a new default',
    () async {
      final repository = AddressRepository(apiClient: await signedInClient());

      Future<int> add(String label) async {
        final result = await repository.create(
          label: label,
          line1: 'A-1',
          localitySlug: 'galleria-market-1',
          pincode: '201016',
        );
        return result.fold((failure) => fail('$failure'), (saved) => saved.id!);
      }

      final home = await add('Home');
      final office = await add('Office');

      // The first one is the default; removing it must leave the account
      // with one, which is the behaviour the screen draws from.
      final result = await repository.delete(home);

      result.fold((failure) => fail('expected a delete, got: $failure'), (
        remaining,
      ) {
        expect(remaining, hasLength(1));
        expect(remaining.single.id, office);
        expect(
          remaining.single.isDefault,
          isTrue,
          reason: 'the server promotes another when the default goes',
        );
      });
      expect(repository.count, 1);
      expect(repository.defaultAddress?.id, office);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'deleting one that is already gone says so rather than pretending',
    () async {
      final repository = AddressRepository(apiClient: await signedInClient());

      final result = await repository.delete(999999999);

      result.fold(
        (failure) => expect(failure.errorCode, 'ADDRESS_NOT_FOUND'),
        (remaining) => fail('expected a refusal, got $remaining'),
      );
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'setting a default unsets the one before it',
    () async {
      final repository = AddressRepository(apiClient: await signedInClient());

      Future<int> add(String label) async {
        final result = await repository.create(
          label: label,
          line1: 'A-1',
          localitySlug: 'galleria-market-1',
          pincode: '201016',
        );
        return result.fold((failure) => fail('$failure'), (saved) => saved.id!);
      }

      final home = await add('Home');
      final office = await add('Office');

      final result = await repository.setDefault(office);

      result.fold((failure) => fail('expected it to be set, got: $failure'), (
        saved,
      ) {
        expect(saved.id, office);
        expect(saved.isDefault, isTrue);
      });
      // Exactly one, and it is the one just asked for.
      final defaults = repository.loaded.where((a) => a.isDefault);
      expect(defaults, hasLength(1));
      expect(defaults.single.id, office);
      expect(repository.loaded.firstWhere((a) => a.id == home).isDefault,
          isFalse);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'the endpoint toggles, which is why the app must not ask twice',
    () async {
      // Documents the backend's behaviour rather than the app's: asking for
      // the current default again CLEARS it, leaving the account with none.
      // AddressesBloc refuses the second call; this is what it is refusing.
      final repository = AddressRepository(apiClient: await signedInClient());

      final created = await repository.create(
        label: 'Home',
        line1: 'A-1',
        localitySlug: 'galleria-market-1',
      );
      final id = created.fold((failure) => fail('$failure'), (s) => s.id!);

      // Creating the first address makes it the default.
      expect(repository.loaded.single.isDefault, isTrue);

      // Asking for the default to be the default CLEARS it. The endpoint
      // still answers `isDefault: true`, which is why the repository reads
      // the list back rather than believing what it was told — and why the
      // bloc refuses to make this call at all.
      final answered = await repository.setDefault(id);

      expect(
        repository.loaded.single.isDefault,
        isFalse,
        reason: 'the stored value toggled off',
      );
      answered.fold(
        (failure) => fail('expected 200, got: $failure'),
        (saved) => expect(
          saved.isDefault,
          isFalse,
          reason: 'the repository reports the list, not the response',
        ),
      );

      // And again puts it back, which is what makes it a toggle.
      await repository.setDefault(id);
      expect(repository.loaded.single.isDefault, isTrue);
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'editing changes only what was sent',
    () async {
      final repository = AddressRepository(apiClient: await signedInClient());

      final created = await repository.create(
        label: 'Home',
        line1: 'A-1',
        line2: 'Block C',
        landmark: 'By the gate',
        localitySlug: 'galleria-market-1',
        pincode: '201016',
      );
      final original = created.fold((f) => fail('$f'), (saved) => saved);

      final result = await repository.update(original.id!, label: 'Work');

      result.fold((failure) => fail('expected an update, got: $failure'), (
        saved,
      ) {
        expect(saved.label, 'Work');
        // Everything left out keeps what it had.
        expect(saved.line1, 'A-1');
        expect(saved.line2, 'Block C');
        expect(saved.landmark, 'By the gate');
        expect(saved.pincode, '201016');
        expect(saved.localityName, 'Galleria Market 1');
        expect(saved.isDefault, original.isDefault);
      });
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'acting on an address that is not there says so',
    () async {
      final repository = AddressRepository(apiClient: await signedInClient());

      final promoted = await repository.setDefault(999999999);
      final edited = await repository.update(999999999, label: 'x');

      promoted.fold(
        (failure) => expect(failure.errorCode, isNotNull),
        (saved) => fail('expected a refusal, got $saved'),
      );
      edited.fold(
        (failure) => expect(failure.errorCode, isNotNull),
        (saved) => fail('expected a refusal, got $saved'),
      );
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
      final removal = await dio.delete('/api/v1/user/addresses/1');
      final promotion = await dio.put('/api/v1/user/addresses/1/default');
      final edit = await dio.patch(
        '/api/v1/user/addresses/1',
        data: const {'label': 'x'},
      );

      expect(response.statusCode, 401);
      expect(removal.statusCode, 401, reason: 'nor can anybody delete one');
      expect(promotion.statusCode, 401, reason: 'nor promote one');
      expect(edit.statusCode, 401, reason: 'nor edit one');
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
