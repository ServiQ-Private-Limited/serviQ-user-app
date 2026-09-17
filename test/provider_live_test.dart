import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/provider/repository/provider_api_repository.dart';

/// The five provider endpoints against the real backend.
///
/// Tagged so it can be excluded: `flutter test --exclude-tags live`. They are
/// all public, so nothing here signs in — which is itself part of what is
/// being checked, because the page is readable signed out.
void main() {
  const baseUrl = 'http://13.207.78.186:8080';
  const slug = 'dev-electricals';

  ProviderApiRepository repository() {
    final apiClient = APIClient(baseUrl: baseUrl);
    apiClient.dio.options.baseUrl = baseUrl;
    return ProviderApiRepository(apiClient: apiClient);
  }

  test(
    'the profile comes back in the shape the page reads',
    () async {
      final result = await repository().profile(slug);

      result.fold((failure) => fail('expected a provider, got: $failure'), (
        provider,
      ) {
        expect(provider.slug, slug);
        expect(provider.providerId, isNotEmpty);
        expect(provider.name, isNotEmpty);
        // The tabs are all drawn from these.
        expect(provider.categories, isNotEmpty);
        expect(provider.availability, hasLength(7));
        expect(provider.homeLocality, isNotNull);
        // Whatever the counts are, the rating must not divide by zero.
        expect(provider.rating.shareAt(5), isA<double>());
      });
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'services, products and hours each answer on their own',
    () async {
      final source = repository();

      final services = await source.services(slug);
      final products = await source.products(slug);
      final hours = await source.availability(slug);

      services.fold(
        (failure) => fail('services: $failure'),
        (list) => expect(list.every((s) => s.name.isNotEmpty), isTrue),
      );
      products.fold(
        (failure) => fail('products: $failure'),
        (list) => expect(list.every((p) => p.name.isNotEmpty), isTrue),
      );
      hours.fold((failure) => fail('hours: $failure'), (days) {
        expect(days, hasLength(7));
        expect(days.map((d) => d.dayOfWeek).toSet(), {1, 2, 3, 4, 5, 6, 7});
      });
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'the About payload and the per-tab endpoints agree',
    () async {
      // The page seeds three tabs from the profile call rather than asking
      // again; that is only safe while the two say the same thing.
      final source = repository();
      final profile = await source.profile(slug);
      final services = await source.services(slug);
      final products = await source.products(slug);

      final fromProfile = profile.fold((f) => fail('$f'), (p) => p);
      final fromServices = services.fold((f) => fail('$f'), (l) => l);
      final fromProducts = products.fold((f) => fail('$f'), (l) => l);

      expect(
        fromProfile.services.map((s) => s.id).toSet(),
        fromServices.map((s) => s.id).toSet(),
      );
      expect(
        fromProfile.products.map((p) => p.id).toSet(),
        fromProducts.map((p) => p.id).toSet(),
      );
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 90)),
  );

  test(
    'reviews come back as a page, even with nothing on it',
    () async {
      final result = await repository().reviews(slug);

      result.fold((failure) => fail('expected a page, got: $failure'), (page) {
        expect(page.page, 0);
        expect(page.size, greaterThan(0));
        expect(page.totalItems, greaterThanOrEqualTo(0));
        expect(page.hasNext, isA<bool>());
      });
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'a slug nobody answers to is a refusal, not an empty provider',
    () async {
      final result = await repository().profile('no-such-shop');

      result.fold(
        (failure) => expect(failure.errorCode, 'PROVIDER_NOT_FOUND'),
        (provider) => fail('expected a refusal, got $provider'),
      );
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 60)),
  );

  test(
    'the page is public — none of the five needs a token',
    () async {
      // Raw Dio rather than APIClient: the app's client is a singleton that
      // may already carry the auth interceptor, so asking it would prove
      // nothing about an unsigned request.
      final dio = Dio(
        BaseOptions(baseUrl: baseUrl, validateStatus: (_) => true),
      );

      for (final path in const [
        '',
        '/services',
        '/products',
        '/availability',
        '/reviews',
      ]) {
        final response = await dio.get('/api/v1/user/providers/$slug$path');
        expect(
          response.statusCode,
          200,
          reason: '$path should answer without a token',
        );
      }
    },
    tags: 'live',
    timeout: const Timeout(Duration(seconds: 90)),
  );
}
