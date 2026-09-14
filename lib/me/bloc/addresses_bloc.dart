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
