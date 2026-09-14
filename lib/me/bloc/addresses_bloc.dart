import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';
import 'package:local_markerplace/network/failure.dart';

part 'addresses_event.dart';
part 'addresses_state.dart';

/// The seeker's saved addresses.
class AddressesBloc extends Bloc<AddressesEvent, AddressesState> {
  final AddressRepository addressRepository;

  AddressesBloc({required this.addressRepository})
    : super(const AddressesState.initial()) {
    on<AddressesRequested>(_onRequested);
    on<AddressDeleted>(_onDeleted);
    on<AddressDefaultSet>(_onDefaultSet);
    on<AddressUpdated>(_onUpdated);
    on<DeleteFailureDismissed>(_onDeleteFailureDismissed);
  }

  /// The first load, and the retry — which is why it clears the failure it
  /// is retrying.
  Future<void> _onRequested(
    AddressesRequested event,
    Emitter<AddressesState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, failure: null, failedAt: null));

    final result = await addressRepository.addresses();
    result.fold(
      (failure) => emit(
        state.copyWith(
          isLoading: false,
          failure: failure,
          failedAt: DateTime.now(),
        ),
      ),
      (addresses) => emit(
        state.copyWith(
          isLoading: false,
          addresses: _defaultFirst(addresses),
          hasLoaded: true,
          failure: null,
          failedAt: null,
        ),
      ),
    );
  }

  /// Removes an address.
  ///
  /// The list is taken from what the endpoint answers with rather than by
  /// dropping the row here: deleting the default promotes another one, and a
  /// locally-pruned list would show a seeker no default at all.
  Future<void> _onDeleted(
    AddressDeleted event,
    Emitter<AddressesState> emit,
  ) async {
    if (state.isBusy) return;
    emit(state.copyWith(deletingId: event.id, deleteFailure: null));

    final result = await addressRepository.delete(event.id);

    await result.fold(
      (failure) async {
        // Already gone — somebody removed it on another device. The row is
        // wrong either way, so the list is reloaded rather than the seeker
        // being told off for deleting something twice.
        if (failure.errorCode == 'ADDRESS_NOT_FOUND') {
          emit(state.copyWith(deletingId: null, deleteFailure: null));
          return _onRequested(const AddressesRequested(), emit);
        }
        emit(state.copyWith(deletingId: null, deleteFailure: failure));
      },
      (remaining) async => emit(
        state.copyWith(
          addresses: _defaultFirst(remaining),
          deletingId: null,
          deleteFailure: null,
          hasLoaded: true,
        ),
      ),
    );
  }

  /// Makes one address the one every booking goes to.
  ///
  /// Refused outright when that address already is the default: the endpoint
  /// toggles, so asking twice would clear it and leave the seeker with none.
  /// The screen does not draw the action on a default row either — this is
  /// the belt to that pair of braces.
  Future<void> _onDefaultSet(
    AddressDefaultSet event,
    Emitter<AddressesState> emit,
  ) async {
    if (state.isBusy) return;
    final current = state.addresses.where((a) => a.id == event.id);
    if (current.isNotEmpty && current.first.isDefault) return;

    emit(state.copyWith(promotingId: event.id, deleteFailure: null));

    final result = await addressRepository.setDefault(event.id);

    result.fold(
      (failure) =>
          emit(state.copyWith(promotingId: null, deleteFailure: failure)),
      // The repository read the list back after the call, because the
      // endpoint's own answer says `isDefault: true` whichever way it went.
      // That reloaded list is the one to draw.
      (_) => emit(
        state.copyWith(
          addresses: _defaultFirst(addressRepository.loaded),
          promotingId: null,
          deleteFailure: null,
        ),
      ),
    );
  }

  /// Puts an address changed on the edit screen back into the list.
  void _onUpdated(AddressUpdated event, Emitter<AddressesState> emit) {
    emit(
      state.copyWith(
        addresses: _defaultFirst([
          for (final address in state.addresses)
            if (address.id == event.address.id) event.address else address,
        ]),
      ),
    );
  }

  void _onDeleteFailureDismissed(
    DeleteFailureDismissed event,
    Emitter<AddressesState> emit,
  ) {
    emit(state.copyWith(deleteFailure: null));
  }

  /// The default address at the top, because it is the one that will be used.
  ///
  /// The endpoint returns them by id, which puts the address that matters
  /// wherever it happened to have been created — for an account with twenty
  /// of them that is the bottom of a long scroll. Everything else keeps the
  /// order it came in, so the list does not reshuffle between loads.
  static List<SavedAddress> _defaultFirst(List<SavedAddress> addresses) {
    return [
      ...addresses.where((address) => address.isDefault),
      ...addresses.where((address) => !address.isDefault),
    ];
  }
}
