import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:local_markerplace/discovery/bloc/discovery_bloc.dart';

import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/visit/presentation/my_orders_page.dart';
import 'package:local_markerplace/dashboard/presentation/posts/presentation/my_posts_page.dart';
import 'package:local_markerplace/chat/presentation/chats_page.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/core/app_routes.dart';
import 'package:local_markerplace/discovery/model/locality.dart';
import 'package:local_markerplace/discovery/model/service_category.dart';
import 'package:local_markerplace/discovery/model/service_zone.dart';
import 'package:local_markerplace/dashboard/presentation/posts/presentation/post_screen.dart';
import 'package:local_markerplace/basket/app_bottom_bar.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_tab_bar.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/discovery/presentation/discovery_home_view.dart';
import 'package:local_markerplace/discovery/presentation/explore_zones_view.dart';
import 'package:local_markerplace/discovery/presentation/location_page.dart';
import 'package:local_markerplace/discovery/presentation/locality_page.dart';
import 'package:local_markerplace/discovery/presentation/search_page.dart';
import 'package:local_markerplace/discovery/presentation/services_page.dart';
import 'package:local_markerplace/discovery/presentation/zone_detail_page.dart';
import 'package:local_markerplace/discovery/model/provider_summary.dart';
import 'package:local_markerplace/discovery/repository/discovery_repository.dart';
import 'package:local_markerplace/discovery/repository/home_repository.dart';
import 'package:local_markerplace/network/api_client.dart';
import 'package:local_markerplace/provider/presentation/provider_profile_page.dart';
import 'package:local_markerplace/me/model/saved_provider.dart';
import 'package:local_markerplace/me/model/seeker_account.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';
import 'package:local_markerplace/me/presentation/addresses_page.dart';
import 'package:local_markerplace/me/presentation/edit_profile_page.dart';
import 'package:local_markerplace/me/presentation/kyc_pages.dart';
import 'package:local_markerplace/me/presentation/me_page.dart';
import 'package:local_markerplace/me/presentation/picture_picker_sheet.dart';
import 'package:local_markerplace/me/presentation/saved_providers_page.dart';
import 'package:local_markerplace/me/presentation/sign_out.dart';
import 'package:local_markerplace/me/bloc/me_bloc.dart';
import 'package:local_markerplace/me/repository/me_repository.dart';
import 'package:local_markerplace/onboarding/model/seeker_profile.dart';
import 'package:local_markerplace/onboarding/repository/onboarding_repository.dart';

/// Hosts the two tabbed discovery screens and owns the state they share —
/// which area the seeker is browsing, and which tab is showing.
///
/// The drill-down screens (zone detail, locality, search) are pushed on top
/// of this rather than being tabs of their own, which is why they draw their
/// own copy of the tab bar and route back through [_selectTab].
class DiscoveryShell extends StatelessWidget {
  const DiscoveryShell({
    super.key,
    this.initialTab = DiscoveryTab.home,
    this.initialLocality,
    this.repository = const DiscoveryRepository(),
    this.profiles,
    this.meRepository = const MeRepository(),
    this.homeRepository,
  });

  final DiscoveryTab initialTab;

  /// The area to open on. Null falls back to the area onboarding recorded in
  /// [profiles], and only then to the picker.
  final String? initialLocality;

  final DiscoveryRepository repository;

  /// Where the seeker's profile lives. The area they chose during onboarding
  /// is read from it on launch, and a change made here is written back — so a
  /// returning seeker lands straight on the area they were last browsing
  /// instead of being asked again.
  ///
  /// Null in tests and anywhere the profile is not provided, which simply
  /// means the picker opens.
  final OnboardingRepository? profiles;

  /// Everything the Me tab and its screens read.
  final MeRepository meRepository;

  /// Where home's feed comes from. Null in tests and previews, which then
  /// get a repository pointed at nothing and see the error state — better
  /// than a screen that silently shows seeded data as if it were live.
  final HomeSource? homeRepository;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DiscoveryBloc(
        onboardingRepository: profiles,
        initialLocality: initialLocality,
        initialTab: initialTab,
      )..add(const DiscoveryStarted()),
      child: _DiscoveryShellView(
        repository: repository,
        meRepository: meRepository,
        homeRepository: homeRepository,
      ),
    );
  }
}

class _DiscoveryShellView extends StatefulWidget {
  const _DiscoveryShellView({
    required this.repository,
    required this.meRepository,
    required this.homeRepository,
  });

  final DiscoveryRepository repository;
  final MeRepository meRepository;
  final HomeSource? homeRepository;

  @override
  State<_DiscoveryShellView> createState() => _DiscoveryShellViewState();
}

class _DiscoveryShellViewState extends State<_DiscoveryShellView> {
  DiscoveryBloc get _bloc => context.read<DiscoveryBloc>();

  DiscoveryState get _state => _bloc.state;

  String? get _localityName => _state.localityName;

  SeekerProfile? get _profile => _state.profile;

  /// Opening the picker is a route push, not a build, so it is deferred to
  /// the next frame when the bloc says there is no area on file.
  void _askForLocality() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pickLocality();
    });
  }

  Future<void> _pickLocality() async {
    final bloc = _bloc;
    final locality = await Navigator.of(context).push<Locality>(
      MaterialPageRoute(
        builder: (_) => LocationPage(repository: widget.repository),
      ),
    );
    if (locality == null) return;
    bloc.add(LocalityChosen(locality.name));
  }

  void _selectTab(DiscoveryTab tab) {
    switch (tab) {
      case DiscoveryTab.home:
      case DiscoveryTab.explore:
      case DiscoveryTab.me:
        _bloc.add(DiscoveryTabSelected(tab));
      case DiscoveryTab.posts:
        _openPosts();
    }
  }

  /// Opens the posts board.
  ///
  /// Posts already has a screen of its own outside this flow, so the tab
  /// pushes it rather than duplicating it here. The area travels with it so
  /// the board can name whose neighbourhood it is showing, and the board
  /// pops back with the tab its own bar was used to leave by.
  Future<void> _openPosts({BoardFilter filter = BoardFilter.all}) async {
    final next = await GoRouter.of(context).pushAppRoute<DiscoveryTab>(
      AppRoutes.posts,
      extra: PostsArgs(localityName: _localityName, initialFilter: filter),
    );
    if (!mounted || next == null) return;
    _bloc.add(DiscoveryTabSelected(next));
  }

  /// Sends a drill-down screen's tab tap back to the shell underneath it.
  void _selectTabFromChild(DiscoveryTab tab) {
    if (tab == DiscoveryTab.posts) {
      _openPosts();
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
    _bloc.add(DiscoveryTabSelected(tab));
  }

  void _openPostForm() => GoRouter.of(
    context,
  ).pushAppRoute(AppRoutes.instantForm, extra: _localityName);

  void _push(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: DiscoveryText.heroSubtitle.copyWith(color: AppColor.white),
          ),
        ),
      );
  }

  /// Writes an edited profile back and refreshes the Me tab with it.
  void _saveProfile(String name, Set<String> interestLabels) {
    _bloc.add(ProfileEdited(name: name, interestLabels: interestLabels));
  }

  void _openZone(ServiceZone zone) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ZoneDetailPage(
          zone: zone,
          onLocalityTap: _openLocality,
          onTabSelected: _selectTabFromChild,
          onPost: _openPostForm,
        ),
      ),
    );
  }

  /// [providers] is passed when the caller already has the list — home,
  /// which got it from the endpoint. Without it the page falls back to what
  /// the seeded repository knows, which is what the zone drill-down uses.
  void _openLocality(Locality locality, {List<ProviderSummary>? providers}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LocalityPage(
          localityName: locality.name,
          providers: providers,
          repository: widget.repository,
          onProviderTap: _openProvider,
          onTabSelected: _selectTabFromChild,
          onPost: _openPostForm,
        ),
      ),
    );
  }

  /// The area's slug, as the endpoint wants it — "Galleria Market 1" is
  /// "galleria-market-1". The conversion is the repository's, so there is
  /// one rule for it rather than one per caller.
  String get _localitySlug => HomeRepository.slugFor(_localityName ?? '');

  /// Every way into the conversations — the Me row and home's chat button.
  Future<void> _openChats() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatsPage(
          onTabSelected: _selectTabFromChild,
          onPost: _openPostForm,
          onFindProvider: () {
            Navigator.of(context).pop();
            _bloc.add(const DiscoveryTabSelected(DiscoveryTab.explore));
          },
        ),
      ),
    );
  }

  /// Home's category tiles are a way into the catalogue, not six screens:
  /// "See all" opens it unfiltered, a tile opens it with that chip lit.
  ///
  /// [categories] is the endpoint's own list, handed over so the catalogue's
  /// filter offers the trades home showed rather than a seeded set of its
  /// own.
  Future<void> _openServices({
    String? category,
    List<ServiceCategory>? categories,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ServicesPage(
          localityName: _localityName ?? 'Ajnara Gen X',
          initialCategory: category,
          categories: categories,
        ),
      ),
    );
  }

  /// Every list of providers in the flow ends here.
  void _openProvider(ProviderSummary provider) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProviderProfilePage(
          providerName: provider.name,
          localityName: _localityName ?? 'Ajnara Gen X',
          onTabSelected: _selectTabFromChild,
          onPost: _openPostForm,
        ),
      ),
    );
  }

  void _openSearch() {
    final locality = _localityName;
    if (locality == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchPage(
          localityName: locality,
          repository: widget.repository,
          onProviderTap: _openProvider,
          onTabSelected: _selectTabFromChild,
          onPost: _openPostForm,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<DiscoveryBloc>().state;

    // Nothing on file — a seeker who skipped onboarding, or a fresh install.
    if (state.mustChooseLocality) _askForLocality();

    if (state.isResolvingLocality) {
      // Reading the stored area takes a frame or two. The design's rule is
      // never a spinner, so home wears the shape it is about to become.
      return const Scaffold(
        backgroundColor: AppColor.white,
        body: SafeArea(
          bottom: false,
          child: SkeletonList(
            hasHeader: true,
            caption: 'Loading providers near you',
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColor.white,
      body: SafeArea(bottom: false, child: _body()),
      bottomNavigationBar: AppBottomBar(
        current: state.tab,
        onSelect: _selectTab,
        onPost: _openPostForm,
      ),
    );
  }

  Widget _meView() {
    // The account counts real things — orders, unread chats — so it is built
    // by a bloc that hears about them rather than read as the tab draws.
    return BlocProvider(
      create: (_) => MeBloc(
        meRepository: widget.meRepository,
        visitRepository: VisitRepository.shared,
      )..add(MeRequested(_profile)),
      // The account is built from the profile, and the profile changes on a
      // screen of its own — so the tab is told rather than left holding the
      // one it was opened with.
      child: BlocListener<DiscoveryBloc, DiscoveryState>(
        listenWhen: (previous, current) => previous.profile != current.profile,
        listener: (context, state) =>
            context.read<MeBloc>().add(MeRequested(state.profile)),
        child: BlocBuilder<MeBloc, MeState>(
          builder: (context, state) {
            final account = state.account;
            if (account == null) return const SizedBox.shrink();
            return _me(account);
          },
        ),
      ),
    );
  }

  Widget _me(SeekerAccount account) {
    return MeView(
      account: account,
      onEditProfile: () => _push(
        EditProfilePage(
          account: account,
          onSave: _saveProfile,
          onChangePhoto: _pickPicture,
          onPickLocality: _pickLocality,
        ),
      ),
      onVisits: () => _push(
        MyOrdersPage(
          onTabSelected: _selectTabFromChild,
          onPost: _openPostForm,
          onBrowse: () {
            Navigator.of(context).pop();
            _bloc.add(const DiscoveryTabSelected(DiscoveryTab.explore));
          },
        ),
      ),
      // "My posts" is the seeker's own history — open, accepted and closed —
      // rather than the board narrowed to them.
      onPosts: () => _push(
        MyPostsPage(
          localityName: _localityName,
          onTabSelected: _selectTabFromChild,
          onPost: _openPostForm,
        ),
      ),
      onChats: _openChats,
      onIdentity: () => _push(KycListPage(repository: widget.meRepository)),
      onSavedProviders: () => _push(
        SavedProvidersPage(
          localityName: _localityName ?? account.localityName,
          repository: widget.meRepository,
          onProviderTap: _openSavedProvider,
          onTabSelected: _selectTabFromChild,
          onPost: _openPostForm,
        ),
      ),
      onAddresses: () => _push(
        AddressesPage(
          // A new address is filed under the area already chosen: the
          // endpoint refuses a slug it does not know, and this is the area
          // that decides which providers the seeker sees.
          localityName: _localityName ?? account.localityName,
          onTabSelected: _selectTabFromChild,
          onPost: _openPostForm,
        ),
      ),
      onNotifications: () => _notice('Notification settings — coming soon.'),
      onBecomeProvider: () => _notice('Listing your business — coming soon.'),
      onSignOut: () => confirmSignOut(context, everywhere: false),
      onSignOutEverywhere: () => confirmSignOut(context, everywhere: true),
    );
  }

  Future<void> _pickPicture() async {
    final action = await PicturePickerSheet.show(context);
    if (action == null || !mounted) return;
    _notice('${action.name} — coming soon.');
  }

  void _openSavedProvider(SavedProvider provider) {
    _push(
      ProviderProfilePage(
        providerName: provider.name,
        localityName: _localityName ?? 'Ajnara Gen X',
        onTabSelected: _selectTabFromChild,
      ),
    );
  }

  Widget _body() {
    switch (_state.tab) {
      case DiscoveryTab.home:
        // Until an area is chosen the picker is on top of this anyway, so
        // the header falls back to a neutral label rather than a real one.
        return DiscoveryHomeView(
          localityName: _localityName ?? 'Choose your area',
          repository: widget.repository,
          localitySlug: _localitySlug,
          localityChoiceId: _state.localityChoiceId,
          homeRepository:
              widget.homeRepository ??
              HomeRepository(apiClient: APIClient(baseUrl: '')),
          onChat: _openChats,
          onPost: _openPostForm,
          onChangeLocality: _pickLocality,
          onSearch: _openSearch,
          onProviderTap: _openProvider,
          onSeeAllCategories: (categories) =>
              _openServices(categories: categories),
          onCategoryTap: (category, categories) =>
              _openServices(category: category.label, categories: categories),
          // The full list is the same people home just showed, handed
          // over rather than looked up again — the endpoint is the only
          // thing that knows who actually works in this area.
          onSeeAllProviders: (providers) {
            final locality = _localityName;
            if (locality != null) {
              _openLocality(
                Locality(
                  name: locality,
                  providerCount: providers.length,
                  kind: LocalityKind.society,
                ),
                providers: providers,
              );
            }
          },
        );
      case DiscoveryTab.explore:
        // The seeker already said where they are, so explore opens on that
        // area's societies and markets rather than asking them to pick a
        // zone all over again. Without an area on file there is nothing to
        // open on, and the zone list is the way in.
        final locality = _localityName;
        final zone = locality == null
            ? null
            : widget.repository.zoneOfLocality(locality);
        if (zone == null) {
          return ExploreZonesView(
            repository: widget.repository,
            onZoneTap: _openZone,
            onComingSoonTap: (zone) => showComingSoonNotice(context, zone),
          );
        }
        return ExploreAreaView(
          zone: zone,
          onLocalityTap: _openLocality,
          comingSoon: widget.repository
              .zones()
              .where((other) => !other.isLive)
              .toList(),
          onComingSoonTap: (zone) => showComingSoonNotice(context, zone),
        );
      case DiscoveryTab.me:
        return _meView();
      case DiscoveryTab.posts:
        // Posts opens its own screen rather than rendering here; this only
        // shows if the tab is somehow current.
        return const SizedBox.shrink();
    }
  }
}
