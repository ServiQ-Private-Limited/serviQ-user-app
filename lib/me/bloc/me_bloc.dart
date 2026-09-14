import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/me/model/seeker_account.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';
import 'package:local_markerplace/me/repository/me_repository.dart';
import 'package:local_markerplace/onboarding/model/seeker_profile.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

part 'me_event.dart';
part 'me_state.dart';

/// The Me tab's account.
///
/// The rows count real things — orders booked, chats unread, providers saved,
/// addresses on file — so the account is rebuilt whenever one of them
/// changes, rather than only when the tab happens to be built again.
class MeBloc extends Bloc<MeEvent, MeState> {
  final MeRepository meRepository;
  final VisitRepository visitRepository;
  final AddressRepository addressRepository;

  late final StreamSubscription<void> _visitChanges;
  late final StreamSubscription<void> _addressChanges;

  MeBloc({
    required this.meRepository,
    required this.visitRepository,
    AddressRepository? addressRepository,
  }) : addressRepository = addressRepository ?? AddressRepository.shared,
       super(const MeState.initial()) {
    on<MeRequested>(_onRequested);

    _visitChanges = visitRepository.changes.listen((_) {
      if (!isClosed) add(MeRequested(state.profile));
    });
    // The addresses screen loads the list; this is how the row that counts
    // them hears about it without the tab being rebuilt.
    _addressChanges = this.addressRepository.changes.listen((_) {
      if (!isClosed) add(MeRequested(state.profile));
    });

    // Counted once on open, so the row has a figure before the seeker has
    // ever been to the addresses screen.
    unawaited(this.addressRepository.refreshCount());
  }

  @override
  Future<void> close() {
    _visitChanges.cancel();
    _addressChanges.cancel();
    return super.close();
  }

  void _onRequested(MeRequested event, Emitter<MeState> emit) {
    emit(
      state.copyWith(
        profile: event.profile,
        account: meRepository.account(profile: event.profile),
        isLoading: false,
      ),
    );
  }
}
