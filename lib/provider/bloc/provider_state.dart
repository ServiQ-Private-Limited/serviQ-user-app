part of 'provider_bloc.dart';

class ProviderState extends Equatable {
  /// Null until the page has been asked for.
  final ProviderDetail? profile;

  /// What is in this provider's cart, or null when nothing is. A cart
  /// belongs to one provider, so another store's is not this page's
  /// business.
  final Visit? cart;

  /// The seeker's own area, which the store's free-delivery line names.
  final String localityName;

  final ProviderTab tab;
  final bool isLoading;

  const ProviderState({
    required this.profile,
    required this.cart,
    required this.localityName,
    required this.tab,
    required this.isLoading,
  });

  const ProviderState.initial({
    this.profile,
    this.cart,
    this.localityName = 'Ajnara Gen X',
    this.tab = ProviderTab.services,
    this.isLoading = true,
  });

  ProviderState copyWith({
    ProviderDetail? profile,
    Visit? cart,

    /// Lets a cart that has just been emptied come back as null rather than
    /// keeping the last one that was there.
    bool clearCartWhenEmpty = false,
    String? localityName,
    ProviderTab? tab,
    bool? isLoading,
  }) {
    return ProviderState(
      profile: profile ?? this.profile,
      cart: cart ?? (clearCartWhenEmpty ? null : this.cart),
      localityName: localityName ?? this.localityName,
      tab: tab ?? this.tab,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// "Ajnara Gen X · usually replies in 10 min".
  /// "Galleria Market 1 · usually replies in 1 min" — the line under the
  /// provider's name wherever the cart shows who it is with.
  ///
  /// Built from what the endpoint actually said. It used to read "usually
  /// replies in 10 min" for everybody, which was a number nobody had
  /// measured; a provider the server reports no response time for now simply
  /// has no such clause.
  String get providerLine {
    final detail = profile;
    final area = detail?.homeLocality?.name.isNotEmpty == true
        ? detail!.homeLocality!.name
        : localityName;
    final replies = detail?.responseLine ?? '';
    return replies.isEmpty ? area : '$area · $replies';
  }

  /// A service is one job, so it is on the visit or off it rather than
  /// counted.
  bool isOnVisit(String serviceName) =>
      cart?.services.any((booked) => booked.name == serviceName) ?? false;

  /// How many of a part are in this provider's cart.
  int quantityOf(String productName) {
    for (final part in cart?.parts ?? const <CartProduct>[]) {
      if (part.name == productName) return part.quantity;
    }
    return 0;
  }

  @override
  List<Object?> get props => [profile, cart, localityName, tab, isLoading];
}
