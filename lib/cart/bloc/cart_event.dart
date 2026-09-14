part of 'cart_bloc.dart';

sealed class CartEvent extends Equatable {
  const CartEvent();
}

/// Loads the cart for the services picked on the dashboard: their prices,
/// whether an instant visit is possible, and where the visit would happen.
final class OnFetchCart extends CartEvent {
  final List<ServiceDetails> services;

  const OnFetchCart(this.services);

  @override
  List<Object> get props => [services];
}

/// Loads the days and start times the slot picker offers. Kept separate from
/// [OnFetchCart] because the picker is only opened on demand.
final class OnFetchSlots extends CartEvent {
  const OnFetchSlots();

  @override
  List<Object> get props => [];
}

final class OnChangeBookingMode extends CartEvent {
  final CartBookingMode mode;

  const OnChangeBookingMode(this.mode);

  @override
  List<Object> get props => [mode];
}

/// Takes a service out of the cart.
final class OnRemoveItem extends CartEvent {
  final String itemId;

  const OnRemoveItem(this.itemId);

  @override
  List<Object> get props => [itemId];
}

final class OnSelectSlot extends CartEvent {
  final CartSlot slot;

  const OnSelectSlot(this.slot);

  @override
  List<Object> get props => [slot];
}

final class OnChangeAddress extends CartEvent {
  final SavedAddress address;

  const OnChangeAddress(this.address);

  @override
  List<Object> get props => [address];
}

final class OnToggleBillDetails extends CartEvent {
  const OnToggleBillDetails();

  @override
  List<Object> get props => [];
}

final class OnDismissAlertMessage extends CartEvent {
  const OnDismissAlertMessage();

  @override
  List<Object> get props => [];
}
