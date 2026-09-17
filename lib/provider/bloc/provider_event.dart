part of 'provider_bloc.dart';

sealed class ProviderEvent extends Equatable {
  const ProviderEvent();
}

/// The provider has loaded — attach the cart to them.
///
/// Carries the detail the endpoint returned rather than a name to look up:
/// there is no local catalogue any more, and the cart needs the same facts
/// the page is drawing from.
final class ProviderRequested extends ProviderEvent {
  final ProviderDetail detail;
  final String localityName;
  final ProviderTab initialTab;

  const ProviderRequested({
    required this.detail,
    required this.localityName,
    required this.initialTab,
  });

  @override
  List<Object> get props => [detail, localityName, initialTab];
}

/// Read the cart again, after somewhere that could have changed it.
final class ProviderCartRefreshed extends ProviderEvent {
  const ProviderCartRefreshed();

  @override
  List<Object> get props => [];
}

final class ProviderTabSelected extends ProviderEvent {
  final ProviderTab tab;

  const ProviderTabSelected(this.tab);

  @override
  List<Object> get props => [tab];
}

/// A service the seeker took from the add sheet.
final class ProviderServiceAdded extends ProviderEvent {
  final VisitService service;

  const ProviderServiceAdded(this.service);

  @override
  List<Object> get props => [service];
}

final class ProviderServiceRemoved extends ProviderEvent {
  final String name;

  const ProviderServiceRemoved(this.name);

  @override
  List<Object> get props => [name];
}

/// A part the seeker took from its own page.
final class ProviderPartAdded extends ProviderEvent {
  final CartProduct product;

  const ProviderPartAdded(this.product);

  @override
  List<Object> get props => [product];
}

/// One more or one fewer of a part, straight from the grid.
final class ProviderPartStepped extends ProviderEvent {
  final String name;
  final int delta;

  const ProviderPartStepped({required this.name, required this.delta});

  @override
  List<Object> get props => [name, delta];
}
