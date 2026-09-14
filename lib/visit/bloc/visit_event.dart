part of 'visit_bloc.dart';

sealed class VisitEvent extends Equatable {
  const VisitEvent();
}

/// Open this provider's cart.
final class CartOpened extends VisitEvent {
  final String providerName;

  const CartOpened(this.providerName);

  @override
  List<Object> get props => [providerName];
}

/// Read the cart again after somewhere that could have changed it.
final class CartRefreshed extends VisitEvent {
  const CartRefreshed();

  @override
  List<Object> get props => [];
}

final class CartModeSelected extends VisitEvent {
  final VisitMode mode;

  const CartModeSelected(this.mode);

  @override
  List<Object> get props => [mode];
}

final class CartSlotChosen extends VisitEvent {
  final VisitSlot slot;

  const CartSlotChosen(this.slot);

  @override
  List<Object> get props => [slot];
}

final class CartAddressChosen extends VisitEvent {
  const CartAddressChosen(this.address);

  final SavedAddress address;

  @override
  List<Object?> get props => [address];
}

final class CartPaymentChosen extends VisitEvent {
  final VisitPayment payment;

  const CartPaymentChosen(this.payment);

  @override
  List<Object> get props => [payment];
}

final class ServiceQuantityChanged extends VisitEvent {
  final int index;
  final int quantity;

  const ServiceQuantityChanged({required this.index, required this.quantity});

  @override
  List<Object> get props => [index, quantity];
}

final class PartQuantityChanged extends VisitEvent {
  final int index;
  final int quantity;

  const PartQuantityChanged({required this.index, required this.quantity});

  @override
  List<Object> get props => [index, quantity];
}

/// Book the cart as it stands.
final class CartConfirmed extends VisitEvent {
  const CartConfirmed();

  @override
  List<Object> get props => [];
}
