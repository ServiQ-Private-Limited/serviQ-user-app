import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/network/api_response.dart';
import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/provider/model/provider_detail.dart';

/// What the provider's page reads, endpoint by endpoint.
///
/// An interface as well as a class so a screen can be pumped against canned
/// payloads — a test of the tabs is not a test of the network.
abstract class ProviderSource {
  /// The About tab, which also carries the services, products and hours the
  /// other tabs show first.
  Future<Either<Failure, ProviderDetail>> profile(String slug);

  Future<Either<Failure, List<ProviderServiceItem>>> services(String slug);

  Future<Either<Failure, List<ProviderProductItem>>> products(String slug);

  Future<Either<Failure, List<ProviderAvailabilityDay>>> availability(
    String slug,
  );

  Future<Either<Failure, ProviderReviewPage>> reviews(
    String slug, {
    int page,
    int size,
  });
}

/// The provider endpoints.
///
/// All five are public — they answer the same signed or not — because the
/// page is readable before anybody signs in.
class ProviderApiRepository implements ProviderSource {
  const ProviderApiRepository({required this.apiClient});

  static ProviderApiRepository get shared =>
      ProviderApiRepository(apiClient: APIClient(baseUrl: ''));

  final APIClient apiClient;

  static const _path = '/api/v1/user/providers';

  /// How long a tab waits before calling it a failure. The client's default
  /// is two minutes, which for a screen somebody is looking at is a hang.
  static const _timeout = Duration(seconds: 10);

  /// A page's worth of reviews, matching the size the endpoint reports.
  static const defaultReviewPageSize = 20;

  @override
  Future<Either<Failure, ProviderDetail>> profile(String slug) {
    return _object('$_path/${Uri.encodeComponent(slug)}', ProviderDetail.fromJson);
  }

  @override
  Future<Either<Failure, List<ProviderServiceItem>>> services(String slug) {
    return _list(
      '$_path/${Uri.encodeComponent(slug)}/services',
      ProviderServiceItem.fromJson,
    );
  }

  @override
  Future<Either<Failure, List<ProviderProductItem>>> products(String slug) {
    return _list(
      '$_path/${Uri.encodeComponent(slug)}/products',
      ProviderProductItem.fromJson,
    );
  }

  @override
  Future<Either<Failure, List<ProviderAvailabilityDay>>> availability(
    String slug,
  ) {
    return _list(
      '$_path/${Uri.encodeComponent(slug)}/availability',
      ProviderAvailabilityDay.fromJson,
    );
  }

  @override
  Future<Either<Failure, ProviderReviewPage>> reviews(
    String slug, {
    int page = 0,
    int size = defaultReviewPageSize,
  }) {
    return _object(
      '$_path/${Uri.encodeComponent(slug)}/reviews',
      ProviderReviewPage.fromJson,
      queryParameters: {'page': page, 'size': size},
    );
  }

  /// An endpoint whose `responseData` is one object.
  Future<Either<Failure, T>> _object<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final data = await apiClient.get(
        path,
        queryParameters: queryParameters,
        options: Options(receiveTimeout: _timeout, sendTimeout: _timeout),
      );

      if (data is! Map<String, dynamic>) return const Left(_malformed);

      final response = ApiResponse.fromJson(data, parse);
      final parsed = response.responseData;
      if (!response.isSuccess || parsed == null) {
        return Left(response.toFailure());
      }
      return Right(parsed);
    } on DioException catch (e) {
      return Left(failureFromDioException(e));
    } catch (e) {
      return Left(Failure(errorMessage: e.toString()));
    }
  }

  /// An endpoint whose `responseData` is a bare array rather than the object
  /// [ApiResponse] parses into — so the envelope is read for the verdict and
  /// the list taken off the body itself.
  Future<Either<Failure, List<T>>> _list<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) async {
    try {
      final data = await apiClient.get(
        path,
        options: Options(receiveTimeout: _timeout, sendTimeout: _timeout),
      );

      if (data is! Map<String, dynamic>) return const Left(_malformed);

      final response = ApiResponse.fromJson(data, (json) => json);
      if (!response.isSuccess) return Left(response.toFailure());

      final raw = data['responseData'];
      if (raw is! List) return const Left(_malformed);

      return Right([
        for (final entry in raw)
          if (entry is Map) parse(Map<String, dynamic>.from(entry)),
      ]);
    } on DioException catch (e) {
      return Left(failureFromDioException(e));
    } catch (e) {
      return Left(Failure(errorMessage: e.toString()));
    }
  }

  static const _malformed = Failure(
    errorMessage: 'Unexpected response from the server.',
    errorCode: 'MALFORMED_RESPONSE',
  );
}
