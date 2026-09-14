import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/visit/model/visit.dart';
import 'package:local_markerplace/visit/model/visit_mode.dart';
import 'package:local_markerplace/visit/model/visit_slot.dart';
import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

part 'visit_event.dart';
part 'visit_state.dart';

/// One provider's cart: what is in it, when it is wanted, and how it is
/// paid for.
///
/// The tab at the top of the screen is the cart's mode rather than a
/// highlight over it — the two are set together here, which is what stopped
/// a seeker who agreed with the opening tab from pressing a button that did
/// nothing.
class VisitBloc extends Bloc<VisitEvent, VisitState> {
  final VisitRepository visitRepository;

  VisitBloc({required this.visitRepository})
    : super(const VisitState.initial()) {
    on<CartOpened>(_onCartOpened);
    on<CartRefreshed>(_onCartRefreshed);
    on<CartModeSelected>(_onModeSelected);
    on<CartSlotChosen>(_onSlotChosen);
    on<CartAddressChosen>(_onAddressChosen);
    on<CartPaymentChosen>(_onPaymentChosen);
    on<ServiceQuantityChanged>(_onServiceQuantityChanged);
    on<PartQuantityChanged>(_onPartQuantityChanged);
    on<CartConfirmed>(_onConfirmed);
  }

  void _onCartOpened(CartOpened event, Emitter<VisitState> emit) {
    final cart = visitRepository.cartFor(event.providerName);
    final instantAvailable = visitRepository.instantAvailable;
    final tab =
        cart?.mode ??
        (instantAvailable ? VisitMode.instant : VisitMode.scheduled);

    // The opening tab is committed to the cart, not just lit: a seeker who
    // agrees with it never touches it, and an uncommitted mode left the
    // checkout reading the cart as untimed.
    if (cart != null &&
        cart.mode == null &&
        (tab != VisitMode.instant || instantAvailable)) {
      visitRepository.setMode(event.providerName, tab);
    }

    emit(
      state.copyWith(
        providerName: event.providerName,
        cart: visitRepository.cartFor(event.providerName),
        days: visitRepository.days(),
        instantAvailable: instantAvailable,
        tab: tab,
        isLoading: false,
        clearCartWhenEmpty: true,
      ),
    );
  }

  void _onCartRefreshed(CartRefreshed event, Emitter<VisitState> emit) {
    emit(state.copyWith(cart: _cart(), clearCartWhenEmpty: true));
  }

  void _onModeSelected(CartModeSelected event, Emitter<VisitState> emit) {
    // An instant booking nobody can take is the one thing not written to the
    // cart — there would be nothing to confirm.
    if (event.mode != VisitMode.instant || state.instantAvailable) {
      visitRepository.setMode(state.providerName, event.mode);
    }
    emit(state.copyWith(tab: event.mode, cart: _cart()));
  }

  void _onSlotChosen(CartSlotChosen event, Emitter<VisitState> emit) {
    visitRepository.setSlot(state.providerName, event.slot);
    emit(state.copyWith(cart: _cart()));
  }

  /// Where the provider is being sent. Chosen from the seeker's saved
  /// addresses, so the cart carries one they can actually be found at.
  void _onAddressChosen(
    CartAddressChosen event,
    Emitter<VisitState> emit,
  ) {
    final providerName = state.providerName;
    if (providerName.isEmpty) return;
    visitRepository.setAddress(providerName, event.address);
    emit(state.copyWith(cart: visitRepository.cartFor(providerName)));
  }

  void _onPaymentChosen(CartPaymentChosen event, Emitter<VisitState> emit) {
    visitRepository.setPayment(state.providerName, event.payment);
    emit(state.copyWith(cart: _cart()));
  }

  void _onServiceQuantityChanged(
    ServiceQuantityChanged event,
    Emitter<VisitState> emit,
  ) {
    visitRepository.setQuantityAt(
      state.providerName,
      event.index,
      event.quantity,
    );
    emit(state.copyWith(cart: _cart(), clearCartWhenEmpty: true));
  }

  void _onPartQuantityChanged(
    PartQuantityChanged event,
    Emitter<VisitState> emit,
  ) {
    visitRepository.setPartQuantityAt(
      state.providerName,
      event.index,
      event.quantity,
    );
    emit(state.copyWith(cart: _cart(), clearCartWhenEmpty: true));
  }

  /// Books it. The confirmed visit is put in state so the screen can show
  /// its receipt, and the cart is gone from the repository by then.
  void _onConfirmed(CartConfirmed event, Emitter<VisitState> emit) {
    final booked = visitRepository.confirm(state.providerName);
    emit(state.copyWith(cart: null, clearCartWhenEmpty: true, booked: booked));
  }

  Visit? _cart() => visitRepository.cartFor(state.providerName);
}
