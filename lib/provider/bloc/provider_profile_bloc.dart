import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/provider/model/provider_detail.dart';
import 'package:local_markerplace/provider/repository/provider_api_repository.dart';

part 'provider_profile_event.dart';
part 'provider_profile_state.dart';

/// One provider's page, tab by tab.
///
/// Each tab is loaded by its own event through its own endpoint and carries
/// its own loading, error and empty state — a store whose products fail is
/// still a provider whose About tab reads perfectly well, and taking the
/// whole page away for it would be the wrong answer.
///
/// The About payload already carries services, products and hours, so the
/// first load seeds all four tabs from it and the per-tab endpoints are what
/// a retry and a refresh use.
class ProviderProfileBloc
    extends Bloc<ProviderProfileEvent, ProviderProfileState> {
  final ProviderSource providerSource;

  ProviderProfileBloc({required this.providerSource})
    : super(const ProviderProfileState.initial()) {
    on<ProviderProfileRequested>(_onRequested);
    on<ProviderServicesRequested>(_onServicesRequested);
    on<ProviderProductsRequested>(_onProductsRequested);
    on<ProviderAvailabilityRequested>(_onAvailabilityRequested);
    on<ProviderReviewsRequested>(_onReviewsRequested);
  }

  /// The About tab, and with it the first contents of the other three.
  Future<void> _onRequested(
    ProviderProfileRequested event,
    Emitter<ProviderProfileState> emit,
  ) async {
    emit(
      state.copyWith(
        slug: event.slug,
        isLoading: true,
        failure: null,
        failedAt: null,
      ),
    );

    final result = await providerSource.profile(event.slug);
    result.fold(
      (failure) => emit(
        state.copyWith(
          isLoading: false,
          failure: failure,
          failedAt: DateTime.now(),
        ),
      ),
      (detail) => emit(
        state.copyWith(
          isLoading: false,
          detail: detail,
          hasLoaded: true,
          failure: null,
          failedAt: null,
          // Seeded from the same payload rather than asked for again: the
          // seeker would otherwise watch three more skeletons fill in with
          // what the page already has.
          services: detail.services,
          servicesLoaded: true,
          products: detail.products,
          productsLoaded: true,
          availability: detail.availability,
          availabilityLoaded: true,
        ),
      ),
    );
    // Reviews are not in the About payload, so the tab asks for its own.
    if (!isClosed && state.detail != null) {
      add(const ProviderReviewsRequested());
    }
  }

  Future<void> _onServicesRequested(
    ProviderServicesRequested event,
    Emitter<ProviderProfileState> emit,
  ) async {
    if (state.slug.isEmpty || state.isLoadingServices) return;
    emit(state.copyWith(isLoadingServices: true, servicesFailure: null));

    final result = await providerSource.services(state.slug);
    result.fold(
      (failure) => emit(
        state.copyWith(isLoadingServices: false, servicesFailure: failure),
      ),
      (services) => emit(
        state.copyWith(
          isLoadingServices: false,
          services: services,
          servicesLoaded: true,
          servicesFailure: null,
        ),
      ),
    );
  }

  Future<void> _onProductsRequested(
    ProviderProductsRequested event,
    Emitter<ProviderProfileState> emit,
  ) async {
    if (state.slug.isEmpty || state.isLoadingProducts) return;
    emit(state.copyWith(isLoadingProducts: true, productsFailure: null));

    final result = await providerSource.products(state.slug);
    result.fold(
      (failure) => emit(
        state.copyWith(isLoadingProducts: false, productsFailure: failure),
      ),
      (products) => emit(
        state.copyWith(
          isLoadingProducts: false,
          products: products,
          productsLoaded: true,
          productsFailure: null,
        ),
      ),
    );
  }

  Future<void> _onAvailabilityRequested(
    ProviderAvailabilityRequested event,
    Emitter<ProviderProfileState> emit,
  ) async {
    if (state.slug.isEmpty || state.isLoadingAvailability) return;
    emit(
      state.copyWith(isLoadingAvailability: true, availabilityFailure: null),
    );

    final result = await providerSource.availability(state.slug);
    result.fold(
      (failure) => emit(
        state.copyWith(
          isLoadingAvailability: false,
          availabilityFailure: failure,
        ),
      ),
      (days) => emit(
        state.copyWith(
          isLoadingAvailability: false,
          availability: days,
          availabilityLoaded: true,
          availabilityFailure: null,
        ),
      ),
    );
  }

  Future<void> _onReviewsRequested(
    ProviderReviewsRequested event,
    Emitter<ProviderProfileState> emit,
  ) async {
    if (state.slug.isEmpty || state.isLoadingReviews) return;
    emit(state.copyWith(isLoadingReviews: true, reviewsFailure: null));

    final result = await providerSource.reviews(state.slug, page: event.page);
    result.fold(
      (failure) => emit(
        state.copyWith(isLoadingReviews: false, reviewsFailure: failure),
      ),
      (page) => emit(
        state.copyWith(
          isLoadingReviews: false,
          reviews: page,
          reviewsLoaded: true,
          reviewsFailure: null,
        ),
      ),
    );
  }
}
