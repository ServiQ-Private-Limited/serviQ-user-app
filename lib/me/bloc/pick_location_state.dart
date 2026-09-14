part of 'pick_location_bloc.dart';

// Sentinel so copyWith can tell "not passed" apart from an explicit null.
const _unset = Object();

class PickLocationState extends Equatable {
  /// Where the pin is, and what is there. Null only before the first fix.
  final AddressDraft? draft;

  /// True while the device is being asked where it is.
  final bool isLocating;

  /// True while the pin's new position is being turned into words.
  final bool isResolving;

  final bool isSearching;
  final List<AddressDraft> results;

  final Failure? failure;

  /// True on the states the map should move itself for — a fix or a chosen
  /// search result. False after a drag, because the map is already there and
  /// moving it again would fight the seeker's thumb.
  final bool recentre;

  const PickLocationState({
    required this.draft,
    required this.isLocating,
    required this.isResolving,
    required this.isSearching,
    required this.results,
    required this.failure,
    required this.recentre,
  });

  const PickLocationState.initial({
    this.draft,
    this.isLocating = true,
    this.isResolving = false,
    this.isSearching = false,
    this.results = const [],
    this.failure,
    this.recentre = false,
  });

  PickLocationState copyWith({
    AddressDraft? draft,
    bool? isLocating,
    bool? isResolving,
    bool? isSearching,
    List<AddressDraft>? results,
    Object? failure = _unset,
    bool? recentre,
  }) {
    return PickLocationState(
      draft: draft ?? this.draft,
      isLocating: isLocating ?? this.isLocating,
      isResolving: isResolving ?? this.isResolving,
      isSearching: isSearching ?? this.isSearching,
      results: results ?? this.results,
      failure: failure == _unset ? this.failure : failure as Failure?,
      recentre: recentre ?? false,
    );
  }

  /// Whether Confirm can be pressed.
  ///
  /// A pin with no address behind it is not something to say yes to, and
  /// neither is one whose address is still being looked up.
  bool get canConfirm =>
      draft != null && draft!.isResolved && !isResolving && !isLocating;

  @override
  List<Object?> get props => [
    draft,
    isLocating,
    isResolving,
    isSearching,
    results,
    failure,
    recentre,
  ];
}
