import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/components/states/empty_state.dart';
import 'package:local_markerplace/components/states/error_state.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/notifications/bloc/notification_bloc.dart';
import 'package:local_markerplace/notifications/model/app_notification.dart';
import 'package:local_markerplace/notifications/repository/notification_repository.dart';

/// 09 · 06 — the notifications drawer.
///
/// A sheet over whatever the bell was tapped from, rather than a screen of
/// its own: notifications are a glance, and the design draws the board still
/// visible behind the scrim.
Future<void> showNotificationsSheet(
  BuildContext context, {
  NotificationRepository? repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColor.white,
    // The design's scrim, which is darker than Flutter's default.
    barrierColor: AppColor.discoveryInk.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) => NotificationsSheet(
      repository: repository ?? NotificationRepository.shared,
    ),
  );
}

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key, this.repository});

  /// Defaults to the shared store, which is what the bells count from.
  final NotificationRepository? repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NotificationBloc(
        notificationRepository: repository ?? NotificationRepository.shared,
      )..add(const NotificationsRequested()),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMoreIfNeeded);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_loadMoreIfNeeded)
      ..dispose();
    super.dispose();
  }

  /// Asks for the next page a little before the end, so the list grows under
  /// the thumb rather than stopping dead and then jumping.
  ///
  /// Called after every build as well as on every scroll, because a page
  /// that happens to fit the screen leaves nothing to scroll — and a drawer
  /// that can only load more when there is already more would never load
  /// the rest.
  void _loadMoreIfNeeded() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels > 320) return;
    context.read<NotificationBloc>().add(
      const NotificationsNextPageRequested(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<NotificationBloc>().state;
    if (state.hasNext) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => mounted ? _loadMoreIfNeeded() : null,
      );
    }
    final now = DateTime.now();
    final today = state.todayAt(now);
    final earlier = state.earlierAt(now);

    // The design gives the sheet 694 of 844 — most of the screen, but with
    // the board still showing above it.
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.82,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppColor.discoveryBorder,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 17),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text('Notifications', style: DiscoveryText.sheetTitle),
                ),
                // Nothing to mark once everything has been read, so the
                // action steps back rather than sitting there doing nothing.
                if (state.hasUnread)
                  PressableScale(
                    onTap: state.isMarkingRead
                        ? null
                        : () => context.read<NotificationBloc>().add(
                            const AllNotificationsRead(),
                          ),
                    pressedScale: 0.92,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      // Says it is working rather than looking like a tap
                      // that did nothing, which is all a slow link would
                      // otherwise show.
                      child: Text(
                        state.isMarkingRead ? 'Marking…' : 'Mark all read',
                        style: state.isMarkingRead
                            ? DiscoveryText.link.copyWith(
                                color: AppColor.discoveryTextTertiary,
                              )
                            : DiscoveryText.link,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: state.isLoading
                // Never a spinner: the drawer wears the shape it is about to
                // become.
                ? const SkeletonList(caption: 'Loading your notifications')
                : state.failure != null
                ? _error(context, state)
                : state.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: 'Nothing here yet',
                    body:
                        'Bookings, offers and messages land here. Nothing '
                        'has happened on your account so far.',
                  )
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      if (today.isNotEmpty) ...[
                        const _SectionHeading('TODAY'),
                        for (final (index, notification) in today.indexed)
                          NotificationRow(
                            notification: notification,
                            index: index,
                          ),
                      ],
                      if (earlier.isNotEmpty) ...[
                        const _SectionHeading('EARLIER'),
                        for (final (index, notification) in earlier.indexed)
                          NotificationRow(
                            notification: notification,
                            index: today.length + index,
                          ),
                      ],
                      if (state.isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: SkeletonListRow(index: 0),
                        )
                      else if (!state.hasNext && state.notifications.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                          child: Text(
                            'That is everything — '
                            '${state.totalItems} in total.',
                            textAlign: TextAlign.center,
                            style: DiscoveryText.fine,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  /// What went wrong, and the way out of it. Being offline and the server
  /// faulting read differently: one is the seeker's to act on, the other
  /// explicitly is not.
  Widget _error(BuildContext context, NotificationState state) {
    final isOffline = state.isOffline;

    return ErrorState(
      isOffline: isOffline,
      title: isOffline ? 'You are offline' : "Couldn't load notifications",
      body: isOffline
          ? 'Nothing loaded because there is no connection. They will be '
                'here when you are back.'
          : 'Something went wrong on our side, not yours. Nothing you did '
                'was lost.',
      onRetry: () =>
          context.read<NotificationBloc>().add(const NotificationsRequested()),
      reference: isOffline ? null : state.failure?.errorCode,
      occurredAt: isOffline ? null : state.failedAt,
    );
  }
}

/// "TODAY" / "EARLIER".
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
      child: Text(label, style: DiscoveryText.fieldLabel),
    );
  }
}

/// One notification: its mark, what happened, what it was about, and how long
/// ago. An unread one sits on a pale tint and carries a dot.
class NotificationRow extends StatelessWidget {
  const NotificationRow({
    super.key,
    required this.notification,
    this.index = 0,
  });

  final AppNotification notification;

  /// Position in the drawer, which staggers the row's entrance.
  final int index;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      index: index,
      child: ColoredBox(
        color: notification.isUnread
            ? AppColor.providerNoteFill
            : AppColor.white,
        child: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: _KindMark(kind: notification.kind),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.only(top: 17, bottom: 16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColor.discoveryBorder),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notification.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DiscoveryText.reviewAuthor.copyWith(
                                height: 18 / 13.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              notification.body,
                              // Two lines, because the server puts what to
                              // do next at the end of the sentence: at one
                              // line "We could not find anyone for
                              // VISFDSY04M5. Try booking a time instead."
                              // reached the seeker as "… Try boo…", which is
                              // the half that mattered.
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: DiscoveryText.meta.copyWith(
                                height: 15 / 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              notification.age,
                              style: DiscoveryText.reviewAge,
                            ),
                            const SizedBox(height: 9),
                            // The unread dot keeps its space either way, so
                            // marking everything read does not reflow the
                            // whole list.
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: notification.isUnread
                                  ? const DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppColor.discoveryAccent,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 38pt disc that says what kind of notification this is.
///
/// The design draws four differently tinted discs with a small glyph in each;
/// the tint is what tells them apart at a glance, so it carries the meaning
/// and the glyph only confirms it.
class _KindMark extends StatelessWidget {
  const _KindMark({required this.kind});

  final NotificationKind kind;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, icon) = switch (kind) {
      NotificationKind.offer => (
        AppColor.artBlueLight,
        AppColor.discoveryAccent,
        Icons.info_outline_rounded,
      ),
      NotificationKind.accepted => (
        AppColor.discoveryLiveTint,
        AppColor.discoveryLiveText,
        Icons.check_rounded,
      ),
      NotificationKind.message => (
        AppColor.artVioletLight,
        AppColor.artVioletDeep,
        Icons.chat_bubble_outline_rounded,
      ),
      NotificationKind.area => (
        AppColor.artAmberLight,
        AppColor.artAmberDeep,
        Icons.info_outline_rounded,
      ),
      // Something did not come good — nobody took the job, a visit fell
      // through. It wears the same red the app uses for a refusal.
      NotificationKind.problem => (
        AppColor.stockLowTint,
        AppColor.authError,
        Icons.priority_high_rounded,
      ),
    };

    return Container(
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: 19, color: foreground),
    );
  }
}
