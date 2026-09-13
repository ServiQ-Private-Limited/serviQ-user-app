import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/discovery/presentation/components/discovery_tab_bar.dart';
import 'package:local_markerplace/discovery/repository/home_repository.dart';
import 'package:local_markerplace/onboarding/model/seeker_profile.dart';
import 'package:local_markerplace/onboarding/repository/onboarding_repository.dart';

part 'discovery_event.dart';
part 'discovery_state.dart';

/// The shell around discovery: which tab is showing, which area is being
/// browsed, and whose profile is behind the Me tab.
///
/// The area is the important part. It is read from the profile onboarding
/// saved, written back when it changes, and handed to every screen that
/// needs it — so a seeker who said where they live is never asked again.
class DiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState> {
  final OnboardingRepository? onboardingRepository;

  /// The area and tab the shell was opened with are the bloc's first state
  /// rather than its first event: the screens underneath build before any
  /// event is handled, and one of them asks the endpoint for whatever area
  /// it is given — which was an empty one for a frame.
  DiscoveryBloc({
    this.onboardingRepository,
    String? initialLocality,
    DiscoveryTab initialTab = DiscoveryTab.home,
  }) : super(
         DiscoveryState.initial(
           localityName: initialLocality,
           tab: initialTab,
           // Resolving from the first frame when there is a profile to read,
           // rather than showing home for a frame and then swapping to the
           // skeleton. That flash built home twice — two blocs, and two of
           // every request they make on opening.
           isResolvingLocality:
               initialLocality == null && onboardingRepository != null,
         ),
       ) {
    on<DiscoveryStarted>(_onStarted);
    on<DiscoveryTabSelected>(_onTabSelected);
    on<LocalityChosen>(_onLocalityChosen);
    on<ProfileEdited>(_onProfileEdited);
  }

  /// Falls back through the places an area can come from: the one the screen
  /// was opened with, then the profile onboarding saved, then asking.
  Future<void> _onStarted(
    DiscoveryStarted event,
    Emitter<DiscoveryState> emit,
  ) async {
    // Already opened on an area, so there is nothing to resolve.
    if (state.localityName != null) return;

    final profiles = onboardingRepository;
    if (profiles == null) {
      emit(state.copyWith(mustChooseLocality: true));
      return;
    }

    // Reading the stored area takes a frame or two, and the picker must not
    // be flashed at a seeker who already told onboarding where they live.
    emit(state.copyWith(isResolvingLocality: true));
    final profile = await profiles.readProfile();
    final locality = profile?.locality ?? '';

    emit(
      state.copyWith(
        isResolvingLocality: false,
        profile: profile,
        localityName: locality.isEmpty ? null : locality,
        mustChooseLocality: locality.isEmpty,
      ),
    );
  }

  void _onTabSelected(
    DiscoveryTabSelected event,
    Emitter<DiscoveryState> emit,
  ) {
    emit(state.copyWith(tab: event.tab));
  }

  /// Records an area the seeker picked, and writes it back so the next
  /// launch opens on it.
  ///
  /// The choice is counted as well as stored: picking the area already
  /// showing leaves the name unchanged, and home still has to go back to the
  /// endpoint for it.
  Future<void> _onLocalityChosen(
    LocalityChosen event,
    Emitter<DiscoveryState> emit,
  ) async {
    emit(
      state.copyWith(
        localityName: event.localityName,
        localityChoiceId: state.localityChoiceId + 1,
        mustChooseLocality: false,
      ),
    );

    final profiles = onboardingRepository;
    if (profiles == null) return;
    // A failure here is not worth interrupting browsing for — the seeker
    // simply gets asked again next time.
    final profile = await profiles.readProfile();
    if (profile == null || profile.locality == event.localityName) return;
    await profiles.saveProfile(profile.copyWith(locality: event.localityName));
  }

  Future<void> _onProfileEdited(
    ProfileEdited event,
    Emitter<DiscoveryState> emit,
  ) async {
    final current = state.profile ?? const SeekerProfile();
    final ids = seekerServiceInterests
        .where((interest) => event.interestLabels.contains(interest.label))
        .map((interest) => interest.id)
        .toSet();
    final updated = current.copyWith(fullName: event.name, interestIds: ids);

    emit(state.copyWith(profile: updated));
    await onboardingRepository?.saveProfile(updated);
  }
}
