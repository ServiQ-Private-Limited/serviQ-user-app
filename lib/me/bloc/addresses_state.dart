part of 'addresses_bloc.dart';

// Sentinel so copyWith can tell "not passed" apart from an explicit null,
// which is what lets a retry clear the failure left by the attempt before it.
const _unset = Object();

class AddressesState extends Equatable {
  final List<SavedAddress> addresses;

  /// True until the first load comes back, and again on a retry.
  final bool isLoading;

  /// True once a load has actually succeeded.
  ///
  /// An empty list and a list that has not arrived look the same otherwise,
  /// and the screen must not say "no addresses yet" to somebody whose
  /// addresses are still on their way.
  final bool hasLoaded;

  final Failure? failure;

  /// When the failure happened, for the line under the error state.
  final DateTime? failedAt;

  const AddressesState({
    required this.addresses,
    required this.isLoading,
    required this.hasLoaded,
    required this.failure,
    required this.failedAt,
  });

  const AddressesState.initial({
    this.addresses = const [],
    this.isLoading = true,
    this.hasLoaded = false,
    this.failure,
    this.failedAt,
  });

  AddressesState copyWith({
    List<SavedAddress>? addresses,
    bool? isLoading,
    bool? hasLoaded,
    Object? failure = _unset,
    Object? failedAt = _unset,
  }) {
    return AddressesState(
      addresses: addresses ?? this.addresses,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      failure: failure == _unset ? this.failure : failure as Failure?,
      failedAt: failedAt == _unset ? this.failedAt : failedAt as DateTime?,
    );
  }

  /// Loaded and genuinely empty, rather than still arriving or broken.
  bool get isEmpty =>
      hasLoaded && !isLoading && failure == null && addresses.isEmpty;

  /// Being offline and the server faulting read differently on the screen.
  bool get isOffline =>
      failure?.errorCode == 'CONNECTION_ERROR' ||
      failure?.errorCode == 'TIMEOUT';

  @override
  List<Object?> get props => [
    addresses,
    isLoading,
    hasLoaded,
    failure,
    failedAt,
  ];
}
