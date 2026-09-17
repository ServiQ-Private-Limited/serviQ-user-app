import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:local_markerplace/components/art/bezier_wash.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/components/states/empty_state.dart';
import 'package:local_markerplace/components/states/error_state.dart';
import 'package:local_markerplace/discovery/bloc/home_bloc.dart';
import 'package:local_markerplace/discovery/model/provider_summary.dart';
import 'package:local_markerplace/discovery/model/service_category.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_header.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_note.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_search_field.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/discovery/presentation/components/category_icon.dart';
import 'package:local_markerplace/discovery/presentation/components/category_tile.dart';
import 'package:local_markerplace/discovery/presentation/components/provider_card.dart';
import 'package:local_markerplace/discovery/presentation/components/section_header.dart';
import 'package:local_markerplace/discovery/repository/discovery_repository.dart';
import 'package:local_markerplace/discovery/repository/home_repository.dart';
import 'package:local_markerplace/notifications/presentation/notifications_sheet.dart';

/// 02 · Home — the seeker's starting point: where they are, what they can
/// search for, the trades on offer and who is working nearby.
///
/// The head of the screen — area, headline and search — sits on a painted
/// wash rather than on white, so the page opens on something to look at. Both
/// lists below it arrive staggered, one item after the next.
///
/// The feed itself belongs to [HomeBloc]: this widget owns the bloc's life
/// and everything below it only reads state and sends events.
class DiscoveryHomeView extends StatelessWidget {
  const DiscoveryHomeView({
    super.key,
    required this.localityName,
    required this.localitySlug,
    required this.homeRepository,
    this.localityChoiceId = 0,
    required this.onChangeLocality,
    required this.onSearch,
    required this.onSeeAllCategories,
    required this.onSeeAllProviders,
    this.onChat,
    this.onPost,
    this.onCategoryTap,
    this.onProviderTap,
    this.repository = const DiscoveryRepository(),
  });

  final String localityName;

  /// What the endpoint is asked for — "galleria-market-1". The name above is
  /// only what the header shows until the server answers with its own.
  final String localitySlug;

  /// Counts how many times the seeker has picked an area.
  ///
  /// The slug alone is not enough to know when to fetch: going to the picker
  /// and choosing the area you are already on leaves it unchanged, and the
  /// seeker who did that has still asked for this area's feed and should get
  /// a fresh one rather than nothing happening.
  final int localityChoiceId;

  final HomeSource homeRepository;

  final VoidCallback onChangeLocality;
  final VoidCallback onSearch;

  /// Opens the catalogue, handed every trade the endpoint returned — not
  /// just the six on the grid, since the filter there offers all of them.
  final ValueChanged<List<ServiceCategory>> onSeeAllCategories;

  /// Opens the full list, handed the providers home is showing so it lists
  /// the same people rather than looking them up again somewhere else.
  final ValueChanged<List<ProviderSummary>> onSeeAllProviders;

  /// Opens the conversations from the header's chat button.
  final VoidCallback? onChat;

  /// Starts a requirement. The area with nobody in it offers this as the way
  /// out, since posting reaches providers who have not listed yet.
  final VoidCallback? onPost;

  /// A tile opens the catalogue narrowed to that trade. It carries the whole
  /// list as well, so the filter there starts from the same set.
  final void Function(ServiceCategory category, List<ServiceCategory> all)?
  onCategoryTap;
  final ValueChanged<ProviderSummary>? onProviderTap;
  final DiscoveryRepository repository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => HomeBloc(homeRepository: homeRepository),
      child: _HomeView(
        localityName: localityName,
        localitySlug: localitySlug,
        localityChoiceId: localityChoiceId,
        onChangeLocality: onChangeLocality,
        onSearch: onSearch,
        onSeeAllCategories: onSeeAllCategories,
        onSeeAllProviders: onSeeAllProviders,
        onChat: onChat,
        onPost: onPost,
        onCategoryTap: onCategoryTap,
        onProviderTap: onProviderTap,
      ),
    );
  }

  /// The rail's cards are a fixed height, because a horizontal list has to be
  /// given one. That means the type inside them has to be handed extra room
  /// when the seeker has scaled it up, rather than being left to overflow.
  static double railHeight(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return 214 + (scale - 1) * 74;
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView({
    required this.localityName,
    required this.localitySlug,
    required this.localityChoiceId,
    required this.onChangeLocality,
    required this.onSearch,
    required this.onSeeAllCategories,
    required this.onSeeAllProviders,
    required this.onChat,
    required this.onPost,
    required this.onCategoryTap,
    required this.onProviderTap,
  });

  final String localityName;
  final String localitySlug;
  final int localityChoiceId;
  final VoidCallback onChangeLocality;
  final VoidCallback onSearch;
  final ValueChanged<List<ServiceCategory>> onSeeAllCategories;
  final ValueChanged<List<ProviderSummary>> onSeeAllProviders;
  final VoidCallback? onChat;
  final VoidCallback? onPost;
  final void Function(ServiceCategory category, List<ServiceCategory> all)?
  onCategoryTap;
  final ValueChanged<ProviderSummary>? onProviderTap;

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(_HomeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Changing area is a different feed, so it is asked for again rather
    // than filtered out of the one already held — and picking an area at all
    // counts, even the one already showing.
    if (oldWidget.localitySlug != widget.localitySlug ||
        oldWidget.localityChoiceId != widget.localityChoiceId) {
      _request();
    }
  }

  void _request() =>
      context.read<HomeBloc>().add(HomeRequested(widget.localitySlug));

  /// Pull-to-refresh has to be told when it is over, and the bloc says so by
  /// coming back out of [HomeState.isRefreshing].
  Future<void> _refresh() async {
    final bloc = context.read<HomeBloc>();
    bloc.add(const HomeRefreshed());
    try {
      await bloc.stream.firstWhere((state) => !state.isRefreshing);
    } catch (_) {
      // The screen was left mid-refresh; there is no indicator to end.
    }
  }

  /// How many trades home shows before "See all".
  ///
  /// The server sends every trade it knows — twenty-three of them — which as
  /// a grid pushes the providers off the bottom of the screen entirely. Six
  /// is two full rows of three, so the grid ends square and the providers
  /// start higher up.
  static const _categoriesShown = 6;

  /// Every trade the endpoint returned, as tiles. The catalogue's filter
  /// offers all of them, so they are all converted and only the grid is cut.
  List<ServiceCategory> _allCategories(HomeState state) => [
    for (final category in state.categories)
      ServiceCategory(
        label: category.tradeName,
        icon: categoryIconFor(category.icon),
      ),
  ];

  /// The rail, in the shape the card already reads.
  ///
  /// The payload has no trade for a provider, so the card's second line
  /// names where they work instead of inventing one.
  List<ProviderSummary> _nearby(HomeState state) => [
    for (final provider in state.providersNearYou)
      ProviderSummary(
        name: provider.name,
        slug: provider.slug,
        trade: provider.localityName,
        rating: provider.ratingAverage,
        reviewCount: provider.reviewCount,
        localityName: provider.localityName,
        isOpen: provider.openNow,
        isVerified: provider.verified,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        // The area's name as the server knows it, falling back to what the
        // shell passed in until it answers.
        final localityName = state.localityName ?? widget.localityName;

        return Column(
          children: [
            BezierWash(
              intensity: 0.85,
              child: Column(
                children: [
                  HomeHeader(
                    localityName: localityName,
                    onChangeLocality: widget.onChangeLocality,
                    onNotifications: () => showNotificationsSheet(context),
                    onChat: widget.onChat,
                    unreadChats: state.unreadChats,
                    unreadNotifications: state.unreadNotifications,
                  ),
                  const SizedBox(height: 14),
                  FadeSlideIn(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          'What do you need done?',
                          style: DiscoveryText.headline,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    index: 1,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: DiscoverySearchButton(onTap: widget.onSearch),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading
                  // Never a spinner: home wears the shape it is about to
                  // become.
                  ? const SkeletonList(caption: 'Loading providers near you')
                  // An area the server has never heard of is not an error to
                  // apologise for, so it gets the empty state and not the
                  // error one.
                  : state.isUnknownLocality
                  ? _comingSoon(localityName)
                  : state.failure != null
                  ? _error(state)
                  : _content(state, localityName),
            ),
          ],
        );
      },
    );
  }

  /// An area ServiQ does not cover yet.
  ///
  /// The server has no record of it at all — no trades, no providers, nothing
  /// to draw — so rather than an empty screen or an apology this says the
  /// area is on the way and offers the two things that still work: browse
  /// somewhere that is live, or post and let providers come to you.
  Widget _comingSoon(String localityName) {
    return EmptyState(
      illustrationAsset: 'assets/images/serviq_trusted_providers.svg',
      title: 'Coming soon to your neighbourhood',
      body:
          '$localityName is not on ServiQ yet. We are signing providers up '
          'there now — pick an area nearby in the meantime, or post what you '
          'need and providers close by will see it.',
      primaryLabel: 'Choose another area',
      primaryIcon: Icons.place_outlined,
      onPrimary: widget.onChangeLocality,
      secondaryLabel: widget.onPost == null ? null : 'Post what you need',
      onSecondary: widget.onPost,
    );
  }

  /// What went wrong, and the two ways out of it.
  ///
  /// Being offline and the server faulting read differently: one is
  /// something the seeker can act on, the other explicitly is not theirs to
  /// fix. Only the second carries a reference, because only it is worth
  /// quoting to support.
  Widget _error(HomeState state) {
    final isOffline = state.isOffline;

    return ErrorState(
      isOffline: isOffline,
      title: isOffline ? 'You are offline' : "Couldn't load providers",
      body: isOffline
          ? 'Nothing loaded because there is no connection. Browsing needs '
                'one; everything you had is still here.'
          : 'Something went wrong on our side, not yours. Nothing you did '
                'was lost.',
      onRetry: _request,
      secondaryLabel: 'Change area',
      onSecondary: widget.onChangeLocality,
      reference: isOffline ? null : state.failure?.errorCode,
      occurredAt: isOffline ? null : state.failedAt,
    );
  }

  Widget _content(HomeState state, String localityName) {
    final all = _allCategories(state);
    final categories = all.take(_categoriesShown).toList();
    final nearby = _nearby(state);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColor.discoveryAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 18, bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeader(
                title: 'Categories',
                onSeeAll: () => widget.onSeeAllCategories(all),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: categories.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 92,
                ),
                itemBuilder: (context, index) => CategoryTile(
                  category: categories[index],
                  index: index,
                  onTap: () =>
                      widget.onCategoryTap?.call(categories[index], all),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeader(
                title: 'Near you',
                onSeeAll: () => widget.onSeeAllProviders(nearby),
              ),
            ),
            const SizedBox(height: 10),
            if (nearby.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DiscoveryNote(
                  'No providers in $localityName yet — coming soon.',
                ),
              )
            else
              SizedBox(
                height: DiscoveryHomeView.railHeight(context),
                child: ListView.separated(
                  // Keyed on the area so switching areas starts the rail
                  // at the first card rather than keeping the offset the
                  // previous area's list was scrolled to — and so the
                  // new area's cards play their entrance.
                  key: ValueKey(localityName),
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: nearby.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => ProviderCard(
                    provider: nearby[index],
                    index: index,
                    onTap: () => widget.onProviderTap?.call(nearby[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
