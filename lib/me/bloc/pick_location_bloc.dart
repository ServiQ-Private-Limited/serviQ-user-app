import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/me/model/address_draft.dart';
import 'package:local_markerplace/me/repository/place_lookup.dart';
import 'package:local_markerplace/network/failure.dart';

part 'pick_location_event.dart';
part 'pick_location_state.dart';

/// Step one of adding an address: where it is.
///
/// The map is the input and the address underneath is the output — every
/// event here ends with a pin somewhere and words to go with it, because a
/// seeker cannot confirm a dot.
class PickLocationBloc extends Bloc<PickLocationEvent, PickLocationState> {
  final PlaceLookup placeLookup;

  PickLocationBloc({required this.placeLookup})
    : super(const PickLocationState.initial()) {
    on<PickLocationStarted>(_onStarted);
    // Dragging the map fires continuously; only where it comes to rest
    // matters, so an in-flight lookup is dropped when a later one starts.
    on<PinMoved>(_onPinMoved, transformer: restartable());
    on<LocateMePressed>(_onLocateMe);
    on<LocationSearched>(_onSearched, transformer: restartable());
    on<SearchResultChosen>(_onResultChosen);
    on<SearchDismissed>(_onSearchDismissed);
  }

  Future<void> _onStarted(
    PickLocationStarted event,
    Emitter<PickLocationState> emit,
  ) async {
    // Opened on an address being changed rather than added: start where that
    // address already is, instead of sending the seeker back to their GPS.
    final from = event.startAt;
    if (from != null) {
      emit(state.copyWith(draft: from, isLocating: false));
      return _resolve(from.latitude, from.longitude, emit);
    }
    await _onLocateMe(const LocateMePressed(), emit);
  }

  Future<void> _onLocateMe(
    LocateMePressed event,
    Emitter<PickLocationState> emit,
  ) async {
    emit(state.copyWith(isLocating: true, failure: null));

    final result = await placeLookup.here();
    result.fold(
      (failure) => emit(
        state.copyWith(
          isLocating: false,
          failure: failure,
          // Somewhere to stand rather than a blank map, so the seeker can
          // drag to where they are even when we could not find them.
          draft: state.draft ?? DevicePlaceLookup.fallback,
          recentre: true,
        ),
      ),
      (draft) => emit(
        state.copyWith(
          isLocating: false,
          draft: draft,
          failure: null,
          recentre: true,
        ),
      ),
    );
  }

  Future<void> _onPinMoved(
    PinMoved event,
    Emitter<PickLocationState> emit,
  ) async {
    emit(
      state.copyWith(
        // The pin is where they left it immediately; only the words lag.
        draft: AddressDraft(
          latitude: event.latitude,
          longitude: event.longitude,
        ),
        isResolving: true,
        failure: null,
        recentre: false,
      ),
    );
    await _resolve(event.latitude, event.longitude, emit);
  }

  Future<void> _resolve(
    double latitude,
    double longitude,
    Emitter<PickLocationState> emit,
  ) async {
    final result = await placeLookup.at(
      latitude: latitude,
      longitude: longitude,
    );
    result.fold(
      (failure) => emit(state.copyWith(isResolving: false, failure: failure)),
      (draft) =>
          emit(state.copyWith(isResolving: false, draft: draft, failure: null)),
    );
  }

  Future<void> _onSearched(
    LocationSearched event,
    Emitter<PickLocationState> emit,
  ) async {
    final query = event.query.trim();
    if (query.isEmpty) {
      emit(state.copyWith(results: const [], isSearching: false));
      return;
    }

    emit(state.copyWith(isSearching: true));
    final result = await placeLookup.search(query);
    result.fold(
      (_) => emit(state.copyWith(isSearching: false, results: const [])),
      (results) =>
          emit(state.copyWith(isSearching: false, results: results)),
    );
  }

  void _onResultChosen(
    SearchResultChosen event,
    Emitter<PickLocationState> emit,
  ) {
    emit(
      state.copyWith(
        draft: event.draft,
        results: const [],
        isSearching: false,
        recentre: true,
      ),
    );
  }

  void _onSearchDismissed(
    SearchDismissed event,
    Emitter<PickLocationState> emit,
  ) {
    emit(state.copyWith(results: const [], isSearching: false));
  }
}
