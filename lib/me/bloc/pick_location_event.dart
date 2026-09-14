part of 'pick_location_bloc.dart';

sealed class PickLocationEvent extends Equatable {
  const PickLocationEvent();

  @override
  List<Object?> get props => [];
}

final class PickLocationStarted extends PickLocationEvent {
  const PickLocationStarted({this.startAt});

  /// Where to open. Null means "find the seeker".
  final AddressDraft? startAt;

  @override
  List<Object?> get props => [startAt];
}

final class PinMoved extends PickLocationEvent {
  const PinMoved({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [latitude, longitude];
}

final class LocateMePressed extends PickLocationEvent {
  const LocateMePressed();
}

final class LocationSearched extends PickLocationEvent {
  const LocationSearched(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class SearchResultChosen extends PickLocationEvent {
  const SearchResultChosen(this.draft);

  final AddressDraft draft;

  @override
  List<Object?> get props => [draft];
}

final class SearchDismissed extends PickLocationEvent {
  const SearchDismissed();
}
