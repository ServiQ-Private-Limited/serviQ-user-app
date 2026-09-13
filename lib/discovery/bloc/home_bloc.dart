import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/chat/repository/chat_repository.dart';
import 'package:local_markerplace/discovery/model/home_feed.dart';
import 'package:local_markerplace/notifications/repository/notification_repository.dart';
import 'package:local_markerplace/discovery/repository/home_repository.dart';
import 'package:local_markerplace/network/failure.dart';

part 'home_event.dart';
part 'home_state.dart';

/// Home's feed, and the two things that can happen to it: it arrives, or it
/// doesn't.
///
/// The screen holds no fetching of its own — it says what happened (the area
/// opened, the seeker pulled to refresh, they pressed Try again) and draws
/// whichever state comes back.
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final HomeSource homeRepository;

  /// The two the header badges. They are read here rather than in the header
  /// because both change on screens home cannot see — a thread read, a
  /// drawer emptied — and a badge that only refreshes when home happens to
  /// rebuild is a badge that lies.
  final ChatRepository chatRepository;
  final NotificationRepository notificationRepository;

  final List<StreamSubscription<void>> _badges = [];

  HomeBloc({
    required this.homeRepository,
    ChatRepository? chatRepository,
    NotificationRepository? notificationRepository,
  }) : chatRepository = chatRepository ?? ChatRepository.shared,
       notificationRepository =
           notificationRepository ?? NotificationRepository.shared,
       super(const HomeState.initial()) {
    on<HomeRequested>(_onHomeRequested);
    on<HomeRefreshed>(_onHomeRefreshed);
    on<HomeBadgesChanged>(_onBadgesChanged);

    _badges.addAll([
      this.chatRepository.changes.listen(_onBadgeChange),
      this.notificationRepository.changes.listen(_onBadgeChange),
    ]);
    add(const HomeBadgesChanged());
    // The notification count comes from the server now, so the bell has to
    // ask before it can badge. Failures are the repository's to swallow — a
    // bell that cannot count is a bell without a badge, not an error to put
    // in front of somebody browsing.
    unawaited(this.notificationRepository.refreshBadge());
  }

  void _onBadgeChange(void _) {
    if (!isClosed) add(const HomeBadgesChanged());
  }

  @override
  Future<void> close() {
    for (final badge in _badges) {
      badge.cancel();
    }
    return super.close();
  }

  void _onBadgesChanged(HomeBadgesChanged event, Emitter<HomeState> emit) {
    emit(
      state.copyWith(
        unreadChats: chatRepository.unreadCount,
        unreadNotifications: notificationRepository.unreadCount,
      ),
    );
  }

  /// Opening an area, and re-opening it after a failure.
  ///
  /// This is the one that shows the skeleton: there is nothing on screen
  /// worth keeping, so the screen wears the shape it is about to become.
  Future<void> _onHomeRequested(
    HomeRequested event,
    Emitter<HomeState> emit,
  ) async {
    // No area yet — the shell is still reading the stored profile. Asking
    // with an empty slug is worse than not asking: the server answers it
    // with whichever area it defaults to, and home would show somebody
    // else's providers for the moment before the real one arrives.
    if (event.localitySlug.trim().isEmpty) return;

    emit(
      state.copyWith(
        localitySlug: event.localitySlug,
        isLoading: true,
        failure: null,
        failedAt: null,
      ),
    );
    await _fetch(event.localitySlug, emit);
  }

  /// Pulling the list down.
  ///
  /// Deliberately not a skeleton: the seeker is looking at the feed and
  /// asking for a newer one, and the pull's own indicator already says so.
  Future<void> _onHomeRefreshed(
    HomeRefreshed event,
    Emitter<HomeState> emit,
  ) async {
    if (state.isLoading || state.isRefreshing) return;
    emit(state.copyWith(isRefreshing: true));
    await _fetch(state.localitySlug, emit);
  }

  Future<void> _fetch(String localitySlug, Emitter<HomeState> emit) async {
    final result = await homeRepository.home(localitySlug: localitySlug);

    result.fold(
      // The moment is kept because the error state quotes it: a reference
      // with no time against it is not much use to whoever is asked about it.
      (failure) => emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          failure: failure,
          failedAt: DateTime.now(),
        ),
      ),
      (feed) => emit(
        state.copyWith(
          isLoading: false,
          isRefreshing: false,
          feed: feed,
          failure: null,
          failedAt: null,
        ),
      ),
    );
  }
}
