import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/provider/model/provider_detail.dart';
import 'package:local_markerplace/provider/model/provider_display.dart';
import 'package:local_markerplace/provider/presentation/components/segmented_tabs.dart';
import 'package:local_markerplace/store/model/cart_product.dart';
import 'package:local_markerplace/visit/model/visit.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

part 'provider_event.dart';
part 'provider_state.dart';

/// One provider's page: who they are, and what of theirs is in the cart.
///
/// The two belong together because every row on the page is drawn from both
/// — a service knows whether it is already booked, a part knows how many are
/// in the basket — and reading the cart from inside the build was what made
/// those rows go stale.
class ProviderBloc extends Bloc<ProviderEvent, ProviderState> {
  final VisitRepository visitRepository;

  ProviderBloc({required this.visitRepository})
    : super(const ProviderState.initial()) {
    on<ProviderRequested>(_onProviderRequested);
    on<ProviderCartRefreshed>(_onCartRefreshed);
    on<ProviderTabSelected>(_onTabSelected);
    on<ProviderServiceAdded>(_onServiceAdded);
    on<ProviderServiceRemoved>(_onServiceRemoved);
    on<ProviderPartAdded>(_onPartAdded);
    on<ProviderPartStepped>(_onPartStepped);
  }

  void _onProviderRequested(
    ProviderRequested event,
    Emitter<ProviderState> emit,
  ) {
    emit(
      state.copyWith(
        profile: event.detail,
        localityName: event.localityName,
        tab: event.initialTab,
        cart: visitRepository.cartFor(event.detail.name),
        isLoading: false,
      ),
    );
  }

  /// Re-reads the cart after the seeker has been somewhere that could change
  /// it — the cart screen, or a part's own page.
  void _onCartRefreshed(
    ProviderCartRefreshed event,
    Emitter<ProviderState> emit,
  ) {
    emit(state.copyWith(cart: _cart(), clearCartWhenEmpty: true));
  }

  void _onTabSelected(ProviderTabSelected event, Emitter<ProviderState> emit) {
    emit(state.copyWith(tab: event.tab));
  }

  void _onServiceAdded(
    ProviderServiceAdded event,
    Emitter<ProviderState> emit,
  ) {
    final profile = state.profile;
    if (profile == null) return;
    // Adding never displaces another store's cart: they sit side by side.
    visitRepository.addService(
      providerName: profile.name,
      providerLine: state.providerLine,
      isVerifiedProvider: profile.verified,
      service: event.service,
    );
    emit(state.copyWith(cart: _cart()));
  }

  void _onServiceRemoved(
    ProviderServiceRemoved event,
    Emitter<ProviderState> emit,
  ) {
    final cart = state.cart;
    if (cart == null) return;
    final index = cart.services.indexWhere((s) => s.name == event.name);
    if (index == -1) return;
    visitRepository.removeServiceAt(cart.providerName, index);
    emit(state.copyWith(cart: _cart(), clearCartWhenEmpty: true));
  }

  void _onPartAdded(ProviderPartAdded event, Emitter<ProviderState> emit) {
    final profile = state.profile;
    if (profile == null) return;
    visitRepository.addProduct(
      providerName: profile.name,
      providerLine: state.providerLine,
      isVerifiedProvider: profile.verified,
      product: event.product,
    );
    emit(state.copyWith(cart: _cart()));
  }

  /// Stepping the last one down takes the part out of the cart, which is
  /// what the bin on the button is promising.
  void _onPartStepped(ProviderPartStepped event, Emitter<ProviderState> emit) {
    final cart = state.cart;
    if (cart == null) return;
    final index = cart.parts.indexWhere((part) => part.name == event.name);
    if (index == -1) return;
    visitRepository.setPartQuantityAt(
      cart.providerName,
      index,
      cart.parts[index].quantity + event.delta,
    );
    emit(state.copyWith(cart: _cart(), clearCartWhenEmpty: true));
  }

  Visit? _cart() {
    final profile = state.profile;
    if (profile == null) return null;
    return visitRepository.cartFor(profile.name);
  }
}
