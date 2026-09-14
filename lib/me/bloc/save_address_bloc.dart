import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/me/model/address_draft.dart';
import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';
import 'package:local_markerplace/network/failure.dart';

part 'save_address_event.dart';
part 'save_address_state.dart';

/// Step two of adding an address: which door to knock on, and what to call it.
class SaveAddressBloc extends Bloc<SaveAddressEvent, SaveAddressState> {
  final AddressRepository addressRepository;

  /// The area the address is filed under.
  ///
  /// The endpoint refuses a slug it does not know, so this is the one the
  /// seeker has already chosen rather than anything read off the map. It is
  /// also the one that decides which providers they see, which is the whole
  /// reason an address carries an area at all.
  final String? localitySlug;

  /// The address being changed, when this is an edit rather than a new one.
  ///
  /// Its presence is what turns Save into a PATCH: the same form, the same
  /// two questions, but against a row that already exists.
  final SavedAddress? editing;

  SaveAddressBloc({
    required this.addressRepository,
    AddressDraft? draft,
    this.localitySlug,
    this.editing,
  }) : super(
         SaveAddressState.initial(
           draft: draft,
           house: editing?.line1 ?? '',
           building: editing?.line2 ?? '',
           label: editing?.label ?? '',
         ),
       ) {
    on<HouseChanged>(_onHouseChanged);
    on<BuildingChanged>(_onBuildingChanged);
    on<LabelSuggestionChosen>(_onSuggestionChosen);
    on<LabelChanged>(_onLabelChanged);
    on<AddressSubmitted>(_onSubmitted);
  }

  void _onHouseChanged(HouseChanged event, Emitter<SaveAddressState> emit) {
    emit(state.copyWith(house: event.value, failure: null));
  }

  void _onBuildingChanged(
    BuildingChanged event,
    Emitter<SaveAddressState> emit,
  ) {
    emit(state.copyWith(building: event.value));
  }

  /// Tapping a chip fills the field rather than replacing it, so the seeker
  /// can start from "Home" and make it "Home — back gate".
  void _onSuggestionChosen(
    LabelSuggestionChosen event,
    Emitter<SaveAddressState> emit,
  ) {
    emit(state.copyWith(label: event.label, failure: null));
  }

  void _onLabelChanged(LabelChanged event, Emitter<SaveAddressState> emit) {
    emit(state.copyWith(label: event.value, failure: null));
  }

  Future<void> _onSubmitted(
    AddressSubmitted event,
    Emitter<SaveAddressState> emit,
  ) async {
    if (!state.canSave || state.isSaving) return;
    emit(state.copyWith(isSaving: true, failure: null));

    final existing = editing;
    final result = existing == null
        ? await _create(event)
        : await _update(existing);

    result.fold(
      (failure) => emit(state.copyWith(isSaving: false, failure: failure)),
      (saved) => emit(state.copyWith(isSaving: false, saved: saved)),
    );
  }

  Future<Either<Failure, SavedAddress>> _create(AddressSubmitted event) {
    // Adding always comes through the map, so there is always a pin here.
    final draft = state.draft!;
    return addressRepository.create(
      label: state.label.trim(),
      line1: state.house.trim(),
      line2: state.building.trim(),
      // What the geocoder read off the map, kept as the landmark: it is the
      // only place the street the pin actually landed on survives, and a
      // provider reading the address wants it.
      landmark: draft.formattedAddress,
      localitySlug: localitySlug,
      // Read off the map rather than typed: the design's form has no pincode
      // field, and the geocoder already established it.
      pincode: draft.pincode,
      latitude: draft.latitude,
      longitude: draft.longitude,
      isDefault: event.makeDefault,
    );
  }

  /// A partial update, so a field this form does not ask about keeps what it
  /// had. The pin only travels when the seeker actually moved it — an
  /// address created through the API has no coordinates, and sending zeroes
  /// would put one on a map in the sea.
  Future<Either<Failure, SavedAddress>> _update(SavedAddress existing) {
    final draft = state.draft;
    // Only when the seeker actually picked a new spot. An address the API
    // created has no coordinates at all, and nothing here invents any — the
    // fields are simply left out, which the endpoint treats as "unchanged".
    final moved =
        draft != null &&
        (draft.latitude != existing.lat || draft.longitude != existing.lng);

    return addressRepository.update(
      existing.id!,
      label: state.label.trim(),
      line1: state.house.trim(),
      line2: state.building.trim(),
      landmark: moved && draft.isResolved ? draft.formattedAddress : null,
      pincode: moved && draft.pincode.isNotEmpty ? draft.pincode : null,
      latitude: moved ? draft.latitude : null,
      longitude: moved ? draft.longitude : null,
    );
  }
}
