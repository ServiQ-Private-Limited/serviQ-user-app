import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/provider/bloc/provider_profile_bloc.dart';
import 'package:local_markerplace/provider/model/provider_detail.dart';
import 'package:local_markerplace/provider/model/provider_display.dart';

import '../support/fake_provider_source.dart';

/// The provider endpoints against the payloads they actually return.
///
/// Every expectation here is a field the server sent. Nothing asserts a
/// value the app made up, because there are none to assert.
void main() {
  Map<String, dynamic> dataOf(String raw) =>
      (jsonDecode(raw) as Map<String, dynamic>)['responseData']
          as Map<String, dynamic>;

  ProviderDetail detail() => ProviderDetail.fromJson(dataOf(capturedProvider));

  group('the About payload', () {
    test('parses the way the endpoint sends it', () {
      final provider = detail();

      expect(provider.providerId, 'PRVDEV000001');
      expect(provider.slug, 'dev-electricals');
      expect(provider.name, 'Dev Electricals');
      expect(provider.about, 'Seeded partner for the DEV environment.');
      expect(provider.businessType, 'BOTH');
      expect(provider.entityKind, 'SHOP');
      expect(provider.verified, isTrue);
      expect(provider.openNow, isTrue);
      expect(provider.homeService, isFalse);
      expect(provider.responseTimeMinutes, 1);
      expect(provider.saved, isFalse);
      // Both null, and no endpoint turns a file id into an image, so the
      // page draws none.
      expect(provider.logoFileId, isNull);
      expect(provider.coverFileId, isNull);
    });

    test('the home locality and the areas covered both come through', () {
      final provider = detail();

      expect(provider.homeLocality?.slug, 'galleria-market-1');
      expect(provider.homeLocality?.zoneName, 'Crossing Republik');
      expect(provider.homeLocality?.lat, 28.643);
      expect(provider.coverage.map((l) => l.slug), [
        'city-plaza',
        'galleria-market-1',
        'galleria-market-2',
      ]);
    });

    test("the trades are the server's, not read off a service name", () {
      final provider = detail();

      expect(provider.categories.map((c) => c.tradeName), [
        'Electrician',
        'Appliance Repair',
      ]);
      expect(provider.tradeLine, 'Electrician · Appliance Repair');
    });

    test('an unrated provider is unrated, not zero stars', () {
      final rating = detail().rating;

      expect(rating.average, 0);
      expect(rating.total, 0);
      expect(rating.isRated, isFalse);
      // Five keys, all zero — and a share that does not divide by zero.
      expect(rating.countAt(5), 0);
      expect(rating.shareAt(5), 0);
    });
  });

  group('what the rows draw', () {
    test('prices are the paise the endpoint sent, in rupees', () {
      final services = detail().services;

      expect(services.first.name, 'AC servicing');
      expect(services.first.fromPricePaise, 59900);
      expect(services.first.fromPriceLabel, 'from ₹599');
      // description is null on every service, so the unit is the line.
      expect(services.first.detailLabel, 'per unit');
      expect(services.last.detailLabel, 'per visit');
    });

    test('stock is the count, not a judgement about it', () {
      final products = detail().products;
      final board = products.firstWhere((p) => p.name == 'Extension board');
      final out = products.firstWhere((p) => p.name == 'Reg oos 0123');

      expect(board.priceLabel, '₹349');
      expect(board.stockLabel, '7 in stock');
      expect(board.isInStock, isTrue);
      expect(out.stockLabel, 'Out of stock');
      expect(out.isInStock, isFalse);
    });

    test('a product carries no picture, because none was sent', () {
      expect(detail().products.every((p) => p.imageFileId == null), isTrue);
      expect(detail().products.first.asDisplay.detail, '');
      // Nothing claims a service fits a part: the endpoint does not say.
      expect(detail().products.first.asDisplay.fittingName, isNull);
    });

    test('Sunday is closed even though it carries times', () {
      final week = detail().availability;
      final sunday = week.firstWhere((d) => d.dayOfWeek == 7);

      expect(sunday.dayName, 'Sunday');
      expect(sunday.closed, isTrue);
      expect(sunday.opensAt, '09:00:00');
      expect(sunday.hoursLabel, 'Closed');
      expect(week.first.hoursLabel, '09:00 – 19:00');
    });

    test('the week is written a day at a time', () {
      final block = detail().availability.hoursBlock;

      expect(block.split('\n'), hasLength(7));
      expect(block.split('\n').first, 'Monday · 09:00 – 19:00');
      expect(block.split('\n').last, 'Sunday · Closed');
    });

    test('the address and the areas read off the payload', () {
      final provider = detail();

      expect(
        provider.addressBlock,
        'Shop 12, Ground floor (near the ATM) 201016\n'
        'Galleria Market 1 · Crossing Republik',
      );
      expect(
        provider.coverageBlock,
        'City Plaza\nGalleria Market 1\nGalleria Market 2',
      );
      expect(provider.responseLine, 'usually replies in 1 min');
    });
  });

  group('the reviews page', () {
    test('an empty page is a page, not a fault', () {
      final page = ProviderReviewPage.fromJson(dataOf(capturedReviews));

      expect(page.items, isEmpty);
      expect(page.isEmpty, isTrue);
      expect(page.page, 0);
      expect(page.size, 20);
      expect(page.totalItems, 0);
      expect(page.totalPages, 0);
      expect(page.hasNext, isFalse);
    });
  });

  group('loading the page', () {
    test('one call fills every tab it carries, and reviews ask their own',
        () async {
      final source = FakeProviderSource(
        detail: detail(),
        reviewPage: ProviderReviewPage.fromJson(dataOf(capturedReviews)),
      );
      final bloc = ProviderProfileBloc(providerSource: source);

      bloc.add(const ProviderProfileRequested('dev-electricals'));
      await bloc.stream.firstWhere((s) => s.reviewsLoaded);

      // The About payload already carries services, products and hours, so
      // the seeker does not watch three more skeletons fill in with what the
      // page already has.
      expect(source.asked, [
        'profile:dev-electricals',
        'reviews:dev-electricals:0',
      ]);
      expect(bloc.state.offeredServices, hasLength(3));
      expect(bloc.state.offeredProducts, hasLength(5));
      expect(bloc.state.availability, hasLength(7));
      expect(bloc.state.reviewsAreEmpty, isTrue);
      await bloc.close();
    });

    test('a provider that is not there says so plainly', () async {
      final bloc = ProviderProfileBloc(
        providerSource: FakeProviderSource(
          detail: null,
          profileFailure: const Failure(
            errorMessage: 'Provider not found.',
            errorCode: 'PROVIDER_NOT_FOUND',
          ),
        ),
      );

      bloc.add(const ProviderProfileRequested('no-such-shop'));
      await bloc.stream.firstWhere((s) => !s.isLoading);

      expect(bloc.state.detail, isNull);
      expect(bloc.state.isNotFound, isTrue);
      await bloc.close();
    });

    test('one tab failing leaves the rest of the provider readable', () async {
      final source = FakeProviderSource(
        detail: detail(),
        productsFailure: const Failure(
          errorMessage: 'Something went wrong.',
          errorCode: 'INTERNAL_ERROR',
        ),
      );
      final bloc = ProviderProfileBloc(providerSource: source);

      bloc.add(const ProviderProfileRequested('dev-electricals'));
      await bloc.stream.firstWhere((s) => s.reviewsLoaded);
      bloc.add(const ProviderProductsRequested());
      await bloc.stream.firstWhere((s) => s.productsFailure != null);

      expect(bloc.state.productsFailure?.errorCode, 'INTERNAL_ERROR');
      // The provider is still there, and so are the other tabs.
      expect(bloc.state.detail, isNotNull);
      expect(bloc.state.offeredServices, hasLength(3));
      expect(bloc.state.availability, hasLength(7));
      await bloc.close();
    });

    test('a retry asks again and clears the failure', () async {
      final source = FakeProviderSource(detail: detail());
      final bloc = ProviderProfileBloc(providerSource: source);

      bloc.add(const ProviderProfileRequested('dev-electricals'));
      await bloc.stream.firstWhere((s) => s.reviewsLoaded);
      bloc.add(const ProviderServicesRequested());
      await bloc.stream.firstWhere((s) => !s.isLoadingServices && s.servicesLoaded);

      expect(source.asked, contains('services:dev-electricals'));
      expect(bloc.state.servicesFailure, isNull);
      await bloc.close();
    });

    test('a refresh that fails leaves the tab its content', () async {
      // The About payload seeded the store; a failed refresh must not blank
      // a list the seeker is already reading.
      final source = FakeProviderSource(
        detail: detail(),
        productsFailure: const Failure(
          errorMessage: 'Something went wrong.',
          errorCode: 'INTERNAL_ERROR',
        ),
      );
      final bloc = ProviderProfileBloc(providerSource: source);

      bloc.add(const ProviderProfileRequested('dev-electricals'));
      await bloc.stream.firstWhere((s) => s.reviewsLoaded);
      bloc.add(const ProviderProductsRequested());
      await bloc.stream.firstWhere((s) => s.productsFailure != null);

      expect(bloc.state.productsFailure, isNotNull);
      expect(
        bloc.state.offeredProducts,
        isNotEmpty,
        reason: 'what was already there is still there',
      );
      await bloc.close();
    });

    test('a hidden or withdrawn listing is not offered', () {
      const hidden = ProviderServiceItem(
        id: 9,
        name: 'Hidden job',
        fromPricePaise: 1000,
        visible: false,
        status: 'ACTIVE',
      );
      const withdrawn = ProviderProductItem(
        id: 9,
        name: 'Withdrawn part',
        pricePaise: 1000,
        stockCount: 4,
        status: 'INACTIVE',
      );

      expect(hidden.isOffered, isFalse);
      expect(withdrawn.isOffered, isFalse);
    });
  });
}

/// `/api/v1/user/providers/dev-electricals`, as the endpoint answered it.
///
/// Inline rather than in a fixtures directory: a data file that is not
/// committed alongside its test takes the test down with it.
const capturedProvider = r'''
{
  "responseCode": "200 OK",
  "errorCode": null,
  "responseMessage": "Success",
  "responseTime": "2026-09-17T08:24:12.972764322Z",
  "responseData": {
    "providerId": "PRVDEV000001",
    "slug": "dev-electricals",
    "name": "Dev Electricals",
    "about": "Seeded partner for the DEV environment.",
    "businessType": "BOTH",
    "entityKind": "SHOP",
    "logoFileId": null,
    "coverFileId": null,
    "addressLine": "Shop 12, Ground floor (near the ATM) 201016",
    "homeLocality": {
      "slug": "galleria-market-1",
      "name": "Galleria Market 1",
      "localityType": "MARKET",
      "zoneSlug": "crossing-republik",
      "zoneName": "Crossing Republik",
      "lat": 28.643,
      "lng": 77.442,
      "radiusKm": 0.3,
      "providerCount": 3
    },
    "coverage": [
      {
        "slug": "city-plaza",
        "name": "City Plaza",
        "localityType": "MARKET",
        "zoneSlug": "crossing-republik",
        "zoneName": "Crossing Republik",
        "lat": 28.64,
        "lng": 77.444,
        "radiusKm": 0.3,
        "providerCount": 1
      },
      {
        "slug": "galleria-market-1",
        "name": "Galleria Market 1",
        "localityType": "MARKET",
        "zoneSlug": "crossing-republik",
        "zoneName": "Crossing Republik",
        "lat": 28.643,
        "lng": 77.442,
        "radiusKm": 0.3,
        "providerCount": 3
      },
      {
        "slug": "galleria-market-2",
        "name": "Galleria Market 2",
        "localityType": "MARKET",
        "zoneSlug": "crossing-republik",
        "zoneName": "Crossing Republik",
        "lat": 28.642,
        "lng": 77.443,
        "radiusKm": 0.3,
        "providerCount": 3
      }
    ],
    "categories": [
      {
        "id": 2,
        "slug": "electrical",
        "tradeName": "Electrician",
        "needName": "Electrical & plumbing",
        "icon": "bolt"
      },
      {
        "id": 4,
        "slug": "appliance-repair",
        "tradeName": "Appliance Repair",
        "needName": "Appliance repair",
        "icon": "plug"
      }
    ],
    "openNow": true,
    "homeService": false,
    "responseTimeMinutes": 1,
    "verified": true,
    "rating": {
      "average": 0,
      "total": 0,
      "breakdown": {
        "1": 0,
        "2": 0,
        "3": 0,
        "4": 0,
        "5": 0
      }
    },
    "services": [
      {
        "id": 3,
        "name": "AC servicing",
        "description": null,
        "fromPricePaise": 59900,
        "unit": "per unit",
        "categoryId": 2,
        "visible": true,
        "status": "ACTIVE"
      },
      {
        "id": 1,
        "name": "Fan installation",
        "description": null,
        "fromPricePaise": 49900,
        "unit": "per unit",
        "categoryId": 2,
        "visible": true,
        "status": "ACTIVE"
      },
      {
        "id": 2,
        "name": "Wiring inspection",
        "description": null,
        "fromPricePaise": 79900,
        "unit": "per visit",
        "categoryId": 2,
        "visible": true,
        "status": "ACTIVE"
      }
    ],
    "products": [
      {
        "id": 2,
        "name": "Extension board",
        "description": null,
        "pricePaise": 34900,
        "stockCount": 7,
        "imageFileId": null,
        "categoryId": 2,
        "visible": true,
        "status": "ACTIVE"
      },
      {
        "id": 1,
        "name": "LED bulb 9W",
        "description": null,
        "pricePaise": 12900,
        "stockCount": 38,
        "imageFileId": null,
        "categoryId": 2,
        "visible": true,
        "status": "ACTIVE"
      },
      {
        "id": 14,
        "name": "Reg bulb 0123",
        "description": null,
        "pricePaise": 49900,
        "stockCount": 2,
        "imageFileId": null,
        "categoryId": null,
        "visible": true,
        "status": "ACTIVE"
      },
      {
        "id": 13,
        "name": "Reg fan 0123",
        "description": null,
        "pricePaise": 249900,
        "stockCount": 10,
        "imageFileId": null,
        "categoryId": null,
        "visible": true,
        "status": "ACTIVE"
      },
      {
        "id": 15,
        "name": "Reg oos 0123",
        "description": null,
        "pricePaise": 89900,
        "stockCount": 0,
        "imageFileId": null,
        "categoryId": null,
        "visible": true,
        "status": "ACTIVE"
      }
    ],
    "availability": [
      {
        "dayOfWeek": 1,
        "dayName": "Monday",
        "opensAt": "09:00:00",
        "closesAt": "19:00:00",
        "closed": false
      },
      {
        "dayOfWeek": 2,
        "dayName": "Tuesday",
        "opensAt": "09:00:00",
        "closesAt": "19:00:00",
        "closed": false
      },
      {
        "dayOfWeek": 3,
        "dayName": "Wednesday",
        "opensAt": "09:00:00",
        "closesAt": "19:00:00",
        "closed": false
      },
      {
        "dayOfWeek": 4,
        "dayName": "Thursday",
        "opensAt": "09:00:00",
        "closesAt": "19:00:00",
        "closed": false
      },
      {
        "dayOfWeek": 5,
        "dayName": "Friday",
        "opensAt": "09:00:00",
        "closesAt": "19:00:00",
        "closed": false
      },
      {
        "dayOfWeek": 6,
        "dayName": "Saturday",
        "opensAt": "09:00:00",
        "closesAt": "19:00:00",
        "closed": false
      },
      {
        "dayOfWeek": 7,
        "dayName": "Sunday",
        "opensAt": "09:00:00",
        "closesAt": "19:00:00",
        "closed": true
      }
    ],
    "saved": false
  }
}
''';

/// `/api/v1/user/providers/dev-electricals/reviews`.
const capturedReviews = r'''
{
  "responseCode": "200 OK",
  "errorCode": null,
  "responseMessage": "Success",
  "responseTime": "2026-09-17T08:25:45.586530331Z",
  "responseData": {
    "items": [],
    "page": 0,
    "size": 20,
    "totalItems": 0,
    "totalPages": 0,
    "hasNext": false
  }
}
''';
