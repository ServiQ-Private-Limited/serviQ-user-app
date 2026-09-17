import 'package:dartz/dartz.dart';

import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/provider/model/provider_detail.dart';
import 'package:local_markerplace/provider/repository/provider_api_repository.dart';

/// The provider endpoints without a server behind them.
class FakeProviderSource implements ProviderSource {
  FakeProviderSource({
    required this.detail,
    List<ProviderServiceItem>? services,
    List<ProviderProductItem>? products,
    List<ProviderAvailabilityDay>? availability,
    this.reviewPage = const ProviderReviewPage.empty(),
    this.profileFailure,
    this.servicesFailure,
    this.productsFailure,
    this.availabilityFailure,
    this.reviewsFailure,
    this.delay = Duration.zero,
  }) : serviceList = services ?? detail?.services ?? const [],
       productList = products ?? detail?.products ?? const [],
       availabilityList = availability ?? detail?.availability ?? const [];

  final ProviderDetail? detail;
  final List<ProviderServiceItem> serviceList;
  final List<ProviderProductItem> productList;
  final List<ProviderAvailabilityDay> availabilityList;
  final ProviderReviewPage reviewPage;

  final Failure? profileFailure;
  final Failure? servicesFailure;
  final Failure? productsFailure;
  final Failure? availabilityFailure;
  final Failure? reviewsFailure;

  final Duration delay;

  /// Every path asked for, in order.
  final List<String> asked = <String>[];

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }

  @override
  Future<Either<Failure, ProviderDetail>> profile(String slug) async {
    asked.add('profile:$slug');
    await _wait();
    if (profileFailure != null) return Left(profileFailure!);
    return Right(detail!);
  }

  @override
  Future<Either<Failure, List<ProviderServiceItem>>> services(
    String slug,
  ) async {
    asked.add('services:$slug');
    await _wait();
    if (servicesFailure != null) return Left(servicesFailure!);
    return Right(serviceList);
  }

  @override
  Future<Either<Failure, List<ProviderProductItem>>> products(
    String slug,
  ) async {
    asked.add('products:$slug');
    await _wait();
    if (productsFailure != null) return Left(productsFailure!);
    return Right(productList);
  }

  @override
  Future<Either<Failure, List<ProviderAvailabilityDay>>> availability(
    String slug,
  ) async {
    asked.add('availability:$slug');
    await _wait();
    if (availabilityFailure != null) return Left(availabilityFailure!);
    return Right(availabilityList);
  }

  @override
  Future<Either<Failure, ProviderReviewPage>> reviews(
    String slug, {
    int page = 0,
    int size = ProviderApiRepository.defaultReviewPageSize,
  }) async {
    asked.add('reviews:$slug:$page');
    await _wait();
    if (reviewsFailure != null) return Left(reviewsFailure!);
    return Right(reviewPage);
  }
}
