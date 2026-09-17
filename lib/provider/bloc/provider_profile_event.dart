part of 'provider_profile_bloc.dart';

sealed class ProviderProfileEvent extends Equatable {
  const ProviderProfileEvent();

  @override
  List<Object?> get props => [];
}

/// Load the provider. Also the retry, which is why it clears the failure.
final class ProviderProfileRequested extends ProviderProfileEvent {
  const ProviderProfileRequested(this.slug);

  /// "dev-electricals" — the shop's slug, which is how the endpoint names
  /// a provider.
  final String slug;

  @override
  List<Object?> get props => [slug];
}

final class ProviderServicesRequested extends ProviderProfileEvent {
  const ProviderServicesRequested();
}

final class ProviderProductsRequested extends ProviderProfileEvent {
  const ProviderProductsRequested();
}

final class ProviderAvailabilityRequested extends ProviderProfileEvent {
  const ProviderAvailabilityRequested();
}

final class ProviderReviewsRequested extends ProviderProfileEvent {
  const ProviderReviewsRequested({this.page = 0});

  final int page;

  @override
  List<Object?> get props => [page];
}
