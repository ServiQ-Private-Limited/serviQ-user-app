part of 'provider_profile_bloc.dart';

// Sentinel so copyWith can tell "not passed" apart from an explicit null,
// which is what lets a retry clear the failure left by the attempt before it.
const _unset = Object();

class ProviderProfileState extends Equatable {
  /// Whose page this is.
  final String slug;

  /// Null until the About call comes back.
  final ProviderDetail? detail;

  final bool isLoading;

  /// True once the provider has actually loaded, which is what tells an
  /// empty tab apart from one that has not arrived.
  final bool hasLoaded;

  final Failure? failure;
  final DateTime? failedAt;

  final List<ProviderServiceItem> services;
  final bool isLoadingServices;
  final bool servicesLoaded;
  final Failure? servicesFailure;

  final List<ProviderProductItem> products;
  final bool isLoadingProducts;
  final bool productsLoaded;
  final Failure? productsFailure;

  final List<ProviderAvailabilityDay> availability;
  final bool isLoadingAvailability;
  final bool availabilityLoaded;
  final Failure? availabilityFailure;

  final ProviderReviewPage reviews;
  final bool isLoadingReviews;
  final bool reviewsLoaded;
  final Failure? reviewsFailure;

  const ProviderProfileState({
    required this.slug,
    required this.detail,
    required this.isLoading,
    required this.hasLoaded,
    required this.failure,
    required this.failedAt,
    required this.services,
    required this.isLoadingServices,
    required this.servicesLoaded,
    required this.servicesFailure,
    required this.products,
    required this.isLoadingProducts,
    required this.productsLoaded,
    required this.productsFailure,
    required this.availability,
    required this.isLoadingAvailability,
    required this.availabilityLoaded,
    required this.availabilityFailure,
    required this.reviews,
    required this.isLoadingReviews,
    required this.reviewsLoaded,
    required this.reviewsFailure,
  });

  const ProviderProfileState.initial({
    this.slug = '',
    this.detail,
    this.isLoading = true,
    this.hasLoaded = false,
    this.failure,
    this.failedAt,
    this.services = const [],
    this.isLoadingServices = false,
    this.servicesLoaded = false,
    this.servicesFailure,
    this.products = const [],
    this.isLoadingProducts = false,
    this.productsLoaded = false,
    this.productsFailure,
    this.availability = const [],
    this.isLoadingAvailability = false,
    this.availabilityLoaded = false,
    this.availabilityFailure,
    this.reviews = const ProviderReviewPage.empty(),
    this.isLoadingReviews = false,
    this.reviewsLoaded = false,
    this.reviewsFailure,
  });

  ProviderProfileState copyWith({
    String? slug,
    ProviderDetail? detail,
    bool? isLoading,
    bool? hasLoaded,
    Object? failure = _unset,
    Object? failedAt = _unset,
    List<ProviderServiceItem>? services,
    bool? isLoadingServices,
    bool? servicesLoaded,
    Object? servicesFailure = _unset,
    List<ProviderProductItem>? products,
    bool? isLoadingProducts,
    bool? productsLoaded,
    Object? productsFailure = _unset,
    List<ProviderAvailabilityDay>? availability,
    bool? isLoadingAvailability,
    bool? availabilityLoaded,
    Object? availabilityFailure = _unset,
    ProviderReviewPage? reviews,
    bool? isLoadingReviews,
    bool? reviewsLoaded,
    Object? reviewsFailure = _unset,
  }) {
    return ProviderProfileState(
      slug: slug ?? this.slug,
      detail: detail ?? this.detail,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      failure: failure == _unset ? this.failure : failure as Failure?,
      failedAt: failedAt == _unset ? this.failedAt : failedAt as DateTime?,
      services: services ?? this.services,
      isLoadingServices: isLoadingServices ?? this.isLoadingServices,
      servicesLoaded: servicesLoaded ?? this.servicesLoaded,
      servicesFailure: servicesFailure == _unset
          ? this.servicesFailure
          : servicesFailure as Failure?,
      products: products ?? this.products,
      isLoadingProducts: isLoadingProducts ?? this.isLoadingProducts,
      productsLoaded: productsLoaded ?? this.productsLoaded,
      productsFailure: productsFailure == _unset
          ? this.productsFailure
          : productsFailure as Failure?,
      availability: availability ?? this.availability,
      isLoadingAvailability:
          isLoadingAvailability ?? this.isLoadingAvailability,
      availabilityLoaded: availabilityLoaded ?? this.availabilityLoaded,
      availabilityFailure: availabilityFailure == _unset
          ? this.availabilityFailure
          : availabilityFailure as Failure?,
      reviews: reviews ?? this.reviews,
      isLoadingReviews: isLoadingReviews ?? this.isLoadingReviews,
      reviewsLoaded: reviewsLoaded ?? this.reviewsLoaded,
      reviewsFailure: reviewsFailure == _unset
          ? this.reviewsFailure
          : reviewsFailure as Failure?,
    );
  }

  /// Only what the provider actually offers. A service withdrawn or hidden
  /// is not something a seeker can book.
  List<ProviderServiceItem> get offeredServices =>
      services.where((service) => service.isOffered).toList();

  List<ProviderProductItem> get offeredProducts =>
      products.where((product) => product.isOffered).toList();

  /// Loaded and genuinely empty, rather than still arriving or broken.
  bool get servicesAreEmpty =>
      servicesLoaded &&
      !isLoadingServices &&
      servicesFailure == null &&
      offeredServices.isEmpty;

  bool get productsAreEmpty =>
      productsLoaded &&
      !isLoadingProducts &&
      productsFailure == null &&
      offeredProducts.isEmpty;

  bool get availabilityIsEmpty =>
      availabilityLoaded &&
      !isLoadingAvailability &&
      availabilityFailure == null &&
      availability.isEmpty;

  bool get reviewsAreEmpty =>
      reviewsLoaded &&
      !isLoadingReviews &&
      reviewsFailure == null &&
      reviews.isEmpty;

  /// Being offline and the server faulting read differently on the screen.
  static bool isOffline(Failure? failure) =>
      failure?.errorCode == 'CONNECTION_ERROR' ||
      failure?.errorCode == 'TIMEOUT';

  /// The slug named nobody. Worth saying plainly rather than as a fault.
  bool get isNotFound => failure?.errorCode == 'PROVIDER_NOT_FOUND';

  @override
  List<Object?> get props => [
    slug,
    detail,
    isLoading,
    hasLoaded,
    failure,
    failedAt,
    services,
    isLoadingServices,
    servicesLoaded,
    servicesFailure,
    products,
    isLoadingProducts,
    productsLoaded,
    productsFailure,
    availability,
    isLoadingAvailability,
    availabilityLoaded,
    availabilityFailure,
    reviews,
    isLoadingReviews,
    reviewsLoaded,
    reviewsFailure,
  ];
}
