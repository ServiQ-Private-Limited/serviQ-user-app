part of 'save_address_bloc.dart';

// Sentinel so copyWith can tell "not passed" apart from an explicit null.
const _unset = Object();

class SaveAddressState extends Equatable {
  /// Where the pin was left in step one.
  ///
  /// Null when an address is being edited that has no coordinates — the
  /// endpoint returns `lat` and `lng` as null for anything not created
  /// through the map, and a made-up pin would put somebody's door in the sea.
  final AddressDraft? draft;

  /// "House No / Flat / Floor" — the only part the seeker must type.
  final String house;

  /// "Building & Block No." — optional, as the design marks it.
  final String building;

  /// "Save address as (Home, Office ..)".
  final String label;

  final bool isSaving;

  /// Set once the server has it, which is what closes the flow.
  final SavedAddress? saved;

  final Failure? failure;

  const SaveAddressState({
    required this.draft,
    required this.house,
    required this.building,
    required this.label,
    required this.isSaving,
    required this.saved,
    required this.failure,
  });

  const SaveAddressState.initial({
    this.draft,
    this.house = '',
    this.building = '',
    this.label = '',
    this.isSaving = false,
    this.saved,
    this.failure,
  });

  SaveAddressState copyWith({
    AddressDraft? draft,
    String? house,
    String? building,
    String? label,
    bool? isSaving,
    SavedAddress? saved,
    Object? failure = _unset,
  }) {
    return SaveAddressState(
      draft: draft ?? this.draft,
      house: house ?? this.house,
      building: building ?? this.building,
      label: label ?? this.label,
      isSaving: isSaving ?? this.isSaving,
      saved: saved ?? this.saved,
      failure: failure == _unset ? this.failure : failure as Failure?,
    );
  }

  /// Both halves are needed: a door with no name is hard to pick out of a
  /// list later, and a name with no door is not an address.
  bool get canSave =>
      house.trim().isNotEmpty && label.trim().isNotEmpty && !isSaving;

  @override
  List<Object?> get props => [
    draft,
    house,
    building,
    label,
    isSaving,
    saved,
    failure,
  ];
}
