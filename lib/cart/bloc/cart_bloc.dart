import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:local_markerplace/cart/model/booking_details.dart';
import 'package:local_markerplace/cart/model/cart_bill.dart';
import 'package:local_markerplace/cart/model/cart_booking_mode.dart';
import 'package:local_markerplace/cart/model/cart_item.dart';
import 'package:local_markerplace/cart/model/cart_slot.dart';
import 'package:local_markerplace/cart/repository/cart_repository.dart';
import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/dashboard/model/services.dart';

part 'cart_event.dart';
part 'cart_state.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc({required CartRepository cartRepository})
    : _cartRepository = cartRepository,
      super(const CartState.initial()) {
    on<OnFetchCart>(_onFetchCart);
    on<OnFetchSlots>(_onFetchSlots);
    on<OnChangeBookingMode>(_onChangeBookingMode);
    on<OnRemoveItem>(_onRemoveItem);
    on<OnSelectSlot>(_onSelectSlot);
    on<OnChangeAddress>(_onChangeAddress);
    on<OnToggleBillDetails>(_onToggleBillDetails);
    on<OnDismissAlertMessage>(_onDismissAlertMessage);
  }

  final CartRepository _cartRepository;

  /// Loads everything the cart shows before the customer touches anything.
  /// The three calls are independent, so they run together rather than in a
  /// chain — the page is blocked on the slowest, not on their sum.
  Future<void> _onFetchCart(OnFetchCart event, Emitter<CartState> emit) async {
    emit(state.copyWith(cartLoading: true));

    // Started together, awaited in turn: the page waits for the slowest call
    // rather than for all three back to back.
    final itemsFuture = _cartRepository.getCartItems(event.services);
    final instantFuture = _cartRepository.isInstantAvailable();
    final detailsFuture = _cartRepository.getBookingDetails();

    final itemsResult = await itemsFuture;
    final instantResult = await instantFuture;
    final detailsResult = await detailsFuture;

    final items = itemsResult.getOrElse(() => const []);
    final instantAvailable = instantResult.getOrElse(() => false);
    final bookingDetails = detailsResult.fold(
      (failure) => null,
      (details) => details,
    );

    emit(
      state.copyWith(
        cartLoading: false,
        items: items,
        instantAvailable: instantAvailable,
        bookingDetails: bookingDetails,
        errorMessage: itemsResult.isLeft()
            ? 'Could not load your cart. Please try again.'
            : '',
      ),
    );
  }

  Future<void> _onFetchSlots(
    OnFetchSlots event,
    Emitter<CartState> emit,
  ) async {
    emit(state.copyWith(slotsLoading: true));
    final result = await _cartRepository.getSlotDays();
    result.fold(
      (failure) => emit(
        state.copyWith(
          slotsLoading: false,
          errorMessage: 'Could not load available times. Please try again.',
        ),
      ),
      (slotDays) =>
          emit(state.copyWith(slotsLoading: false, slotDays: slotDays)),
    );
  }

  void _onChangeBookingMode(
    OnChangeBookingMode event,
    Emitter<CartState> emit,
  ) {
    // A slot already chosen is kept when the customer looks at another tab,
    // so switching back does not cost them the pick.
    emit(state.copyWith(mode: event.mode));
  }

  void _onRemoveItem(OnRemoveItem event, Emitter<CartState> emit) {
    final items = state.items
        .where((item) => item.id != event.itemId)
        .toList();
    emit(state.copyWith(items: items));
  }

  void _onSelectSlot(OnSelectSlot event, Emitter<CartState> emit) {
    // Confirming a slot only makes sense as a scheduled booking, so picking
    // one also moves the cart onto that tab.
    emit(
      state.copyWith(selectedSlot: event.slot, mode: CartBookingMode.schedule),
    );
  }

  /// Where the professional is being sent.
  ///
  /// Written straight into the details on screen rather than re-fetched: the
  /// seeker has just picked it, and a card that blanks and reloads to show
  /// the thing they chose is a worse answer than one that simply changes.
  void _onChangeAddress(OnChangeAddress event, Emitter<CartState> emit) {
    final details = state.bookingDetails;
    if (details == null) return;
    emit(
      state.copyWith(
        bookingDetails: BookingDetails(
          address: event.address.lines.replaceAll('\n', ', '),
          customerName: details.customerName,
          customerPhone: details.customerPhone,
        ),
      ),
    );
  }

  void _onToggleBillDetails(
    OnToggleBillDetails event,
    Emitter<CartState> emit,
  ) {
    emit(state.copyWith(billExpanded: !state.billExpanded));
  }

  void _onDismissAlertMessage(
    OnDismissAlertMessage event,
    Emitter<CartState> emit,
  ) {
    emit(state.copyWith(errorMessage: ''));
  }
}
