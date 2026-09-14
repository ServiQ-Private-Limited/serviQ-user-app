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

  /// The address currently being removed, so its own row can say so while
  /// the rest of the list stays usable.
  final int? deletingId;

  /// The address being made the default. Its row says so, and no second
  /// call can go out while one is in flight — the endpoint toggles, so a
  /// double tap would otherwise clear the default it had just set.
  final int? promotingId;

  /// A delete that was refused. Kept apart from [failure] because the list
  /// is fine — only the one action was.
  final Failure? deleteFailure;

  const AddressesState({
    required this.addresses,
    required this.isLoading,
    required this.hasLoaded,
    required this.failure,
    required this.failedAt,
    required this.deletingId,
    required this.promotingId,
    required this.deleteFailure,
  });

  const AddressesState.initial({
    this.addresses = const [],
    this.isLoading = true,
    this.hasLoaded = false,
    this.failure,
    this.failedAt,
    this.deletingId,
    this.promotingId,
    this.deleteFailure,
  });

  AddressesState copyWith({
    List<SavedAddress>? addresses,
    bool? isLoading,
    bool? hasLoaded,
    Object? failure = _unset,
    Object? failedAt = _unset,
    Object? deletingId = _unset,
    Object? promotingId = _unset,
    Object? deleteFailure = _unset,
  }) {
    return AddressesState(
      addresses: addresses ?? this.addresses,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      failure: failure == _unset ? this.failure : failure as Failure?,
      failedAt: failedAt == _unset ? this.failedAt : failedAt as DateTime?,
      deletingId: deletingId == _unset
          ? this.deletingId
          : deletingId as int?,
      promotingId: promotingId == _unset
          ? this.promotingId
          : promotingId as int?,
      deleteFailure: deleteFailure == _unset
          ? this.deleteFailure
          : deleteFailure as Failure?,
    );
  }

  /// Whether this row is the one on its way out.
  bool isDeleting(int? id) => id != null && id == deletingId;

  /// Whether this row is the one being made the default.
  bool isPromoting(int? id) => id != null && id == promotingId;

  /// True while any row is busy, which is what stops a second action going
  /// out on top of the first.
  bool get isBusy => deletingId != null || promotingId != null;

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
    deletingId,
    promotingId,
    deleteFailure,
  ];
}
