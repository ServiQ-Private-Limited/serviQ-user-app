part of 'addresses_bloc.dart';

sealed class AddressesEvent extends Equatable {
  const AddressesEvent();
}

final class AddressesRequested extends AddressesEvent {
  const AddressesRequested();

  @override
  List<Object> get props => [];
}

final class AddressDeleted extends AddressesEvent {
  const AddressDeleted(this.id);

  /// The server's id — the only thing that names an address to the endpoint.
  final int id;

  @override
  List<Object> get props => [id];
}

final class AddressDefaultSet extends AddressesEvent {
  const AddressDefaultSet(this.id);

  final int id;

  @override
  List<Object> get props => [id];
}

/// An address changed elsewhere — the edit screen — put back into the list.
final class AddressUpdated extends AddressesEvent {
  const AddressUpdated(this.address);

  final SavedAddress address;

  @override
  List<Object> get props => [address];
}

/// Clears the message left by an action that failed, once it has been shown.
final class DeleteFailureDismissed extends AddressesEvent {
  const DeleteFailureDismissed();

  @override
  List<Object> get props => [];
}
