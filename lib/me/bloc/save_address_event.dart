part of 'save_address_bloc.dart';

sealed class SaveAddressEvent extends Equatable {
  const SaveAddressEvent();

  @override
  List<Object?> get props => [];
}

final class HouseChanged extends SaveAddressEvent {
  const HouseChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

final class BuildingChanged extends SaveAddressEvent {
  const BuildingChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

final class LabelSuggestionChosen extends SaveAddressEvent {
  const LabelSuggestionChosen(this.label);

  final String label;

  @override
  List<Object?> get props => [label];
}

final class LabelChanged extends SaveAddressEvent {
  const LabelChanged(this.value);

  final String value;

  @override
  List<Object?> get props => [value];
}

final class AddressSubmitted extends SaveAddressEvent {
  const AddressSubmitted({this.makeDefault = false});

  /// True when this is the seeker's first address, which the server would
  /// make the default anyway — saying so keeps the two in step.
  final bool makeDefault;

  @override
  List<Object?> get props => [makeDefault];
}
