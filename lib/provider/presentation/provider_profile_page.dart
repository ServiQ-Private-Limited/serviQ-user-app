import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_markerplace/basket/app_bottom_bar.dart';
import 'package:local_markerplace/provider/bloc/provider_bloc.dart';
import 'package:local_markerplace/components/app_back_button.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_note.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_tab_bar.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/components/states/error_state.dart';
import 'package:local_markerplace/network/failure.dart';
import 'package:local_markerplace/provider/bloc/provider_profile_bloc.dart';
import 'package:local_markerplace/provider/model/provider_detail.dart';
import 'package:local_markerplace/provider/model/provider_display.dart';
import 'package:local_markerplace/provider/model/provider_service.dart';
import 'package:local_markerplace/provider/model/store_product.dart';
import 'package:local_markerplace/provider/presentation/components/product_card.dart';
import 'package:local_markerplace/provider/presentation/components/provider_hero.dart';
import 'package:local_markerplace/provider/presentation/components/rating_summary.dart';
import 'package:local_markerplace/provider/presentation/components/segmented_tabs.dart';
import 'package:local_markerplace/provider/presentation/components/service_rows.dart';
import 'package:local_markerplace/provider/repository/provider_api_repository.dart';
import 'package:local_markerplace/store/model/cart_product.dart';
import 'package:local_markerplace/store/presentation/product_page.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/presentation/add_to_visit_sheet.dart';
import 'package:local_markerplace/visit/presentation/your_visit_page.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

/// A provider's public page — the destination every path in discovery leads
/// to.
///
/// The page is readable signed out; only connecting and messaging are gated,
/// which is what [isSignedIn] switches. The head scrolls away with the
/// content and the tab strip pins under it, so the four sections behave like
/// one page rather than four.
class ProviderProfilePage extends StatelessWidget {
  const ProviderProfilePage({
    super.key,
    required this.slug,
    this.isSignedIn = true,
    this.initialTab = ProviderTab.services,
    this.localityName = '',
    this.source,
    this.onTabSelected,
    this.onPost,
    this.onChat,
  });

  /// "dev-electricals" — how the endpoint names a provider. Everything on
  /// the page is read from it; nothing is looked up by display name any more.
  final String slug;
  final bool isSignedIn;
  final ProviderTab initialTab;

  /// The seeker's own area, which the store's free-delivery line names.
  final String localityName;
  final ProviderSource? source;
  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;

  /// Opens the conversation with this provider — the existing one if they
  /// have spoken, a new one if they have not. Null where there is nowhere to
  /// send them, and then Chat says so rather than doing nothing.
  final void Function(ProviderDetail provider)? onChat;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        // The page's data, a tab at a time.
        BlocProvider(
          create: (_) =>
              ProviderProfileBloc(
                providerSource: source ?? ProviderApiRepository.shared,
              )..add(ProviderProfileRequested(slug)),
        ),
        // What of theirs is in the cart. Attached once the provider loads,
        // because a cart belongs to a provider the endpoint has named.
        BlocProvider(
          create: (_) => ProviderBloc(visitRepository: VisitRepository.shared),
        ),
      ],
      child: _ProviderProfileView(
        isSignedIn: isSignedIn,
        localityName: localityName,
        initialTab: initialTab,
        onTabSelected: onTabSelected,
        onPost: onPost,
        onChat: onChat,
      ),
    );
  }
}

class _ProviderProfileView extends StatefulWidget {
  const _ProviderProfileView({
    required this.isSignedIn,
    required this.localityName,
    required this.initialTab,
    required this.onTabSelected,
    required this.onPost,
    required this.onChat,
  });

  final bool isSignedIn;
  final String localityName;
  final ProviderTab initialTab;
  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;
  final void Function(ProviderDetail provider)? onChat;

  @override
  State<_ProviderProfileView> createState() => _ProviderProfileViewState();
}

class _ProviderProfileViewState extends State<_ProviderProfileView> {
  ProviderBloc get _bloc => context.read<ProviderBloc>();

  ProviderProfileBloc get _profileBloc => context.read<ProviderProfileBloc>();

  ProviderDetail get _profile => _profileBloc.state.detail!;

  void _gatedAction(String what) {
    if (widget.isSignedIn) {
      _notice('$what — coming soon.');
      return;
    }
    _notice('Sign in to $what.');
  }

  /// Adds one of the provider's services to the visit, then shows it.
  ///
  /// A visit is one provider, so adding from a different profile replaces
  /// whatever was being built — the sheet says so rather than silently
  /// dropping it.
  Future<void> _addToVisit(ProviderService service) async {
    final added = await showAddToVisitSheet(
      context,
      name: service.name,
      detail: service.detail,
      unitPrice: rupeesFrom(service.fromPrice),
    );
    if (added == null || !mounted) return;

    _bloc.add(ProviderServiceAdded(added));
    await _openCart();
  }

  /// Opens a part, and puts it in the cart if the seeker takes it.
  ///
  /// A cart is one provider, like a visit — adding from another store starts
  /// a new one, and the screen says so rather than losing the old one
  /// quietly.
  Future<void> _openProduct(StoreProduct product) async {
    final added = await Navigator.of(context).push<CartProduct>(
      MaterialPageRoute(
        builder: (_) => ProductPage(
          product: product,
          localityName: _bloc.state.localityName,
          onBookFitting: product.fittingName == null
              ? null
              : () => _bookFitting(product.fittingName!),
        ),
      ),
    );
    if (added == null || !mounted) return;

    _bloc.add(ProviderPartAdded(added));
    await _openCart();
  }

  Future<void> _openCart() async {
    final bloc = _bloc;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YourVisitPage(
          providerName: _profile.name,
          localityName: _bloc.state.localityName,
          onAddAnother: () => Navigator.of(context).pop(),
        ),
      ),
    );
    // The cart screen can empty it, so the page asks what is left.
    bloc.add(const ProviderCartRefreshed());
  }

  /// Leaves the store for the service that fits what is being bought. The
  /// two halves of a provider's page are the same person, so this is a tab
  /// switch rather than a new screen.
  void _bookFitting(String serviceName) {
    Navigator.of(context).pop();
    _bloc.add(const ProviderTabSelected(ProviderTab.services));
    final match = _profileBloc.state.offeredServices.where(
      (service) => service.name == serviceName,
    );
    if (match.isEmpty) return;
    _addToVisit(match.first.asDisplay);
  }

  /// Opens the conversation with this provider.
  ///
  /// Signed out there is nothing to open — a thread belongs to an account —
  /// so the action says what signing in would buy them instead.
  void _chat() {
    if (!widget.isSignedIn) {
      _gatedAction('chat');
      return;
    }
    final open = widget.onChat;
    if (open == null) {
      _notice('Chat — coming soon.');
      return;
    }
    open(_profile);
  }

  /// Switches tab, and asks that tab's own endpoint for what it shows.
  ///
  /// The About payload seeded every tab when the page opened, so this is a
  /// refresh rather than a first load: the section keeps what it has while
  /// the call is out, and a stale price or a part that sold out in the
  /// meantime is corrected without the seeker doing anything. It is also
  /// what gives the per-tab endpoints a job — seeded content that is never
  /// refreshed would mean three endpoints nothing ever called.
  void _selectTab(ProviderTab tab) {
    _bloc.add(ProviderTabSelected(tab));
    switch (tab) {
      case ProviderTab.services:
        _profileBloc.add(const ProviderServicesRequested());
      case ProviderTab.store:
        _profileBloc.add(const ProviderProductsRequested());
      case ProviderTab.about:
        _profileBloc.add(const ProviderAvailabilityRequested());
      case ProviderTab.reviews:
        _profileBloc.add(const ProviderReviewsRequested());
    }
  }

  /// Tells the cart bloc who this page is for, once.
  void _attachCart(ProviderDetail detail) {
    if (_bloc.state.profile == detail) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _bloc.state.profile == detail) return;
      _bloc.add(
        ProviderRequested(
          detail: detail,
          localityName: widget.localityName,
          initialTab: widget.initialTab,
        ),
      );
    });
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

  @override
  Widget build(BuildContext context) {
    final data = context.watch<ProviderProfileBloc>().state;

    // The whole page is one provider, so until that one call answers there
    // is nothing to draw and nothing to draw it around.
    if (data.isLoading) return const _ProfileLoading();
    if (data.detail == null) {
      return _ProfileError(
        state: data,
        onRetry: () =>
            _profileBloc.add(ProviderProfileRequested(data.slug)),
      );
    }

    // The cart belongs to a provider the endpoint has named, so it is
    // attached once the call returns — and again if the page is reloaded
    // onto somebody else. Done after the frame rather than in a listener,
    // because the listener would be mounted by the build that already has
    // the detail and so would never see it arrive.
    _attachCart(data.detail!);

    final state = context.watch<ProviderBloc>().state;

    return Scaffold(
      backgroundColor: AppColor.white,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: ProviderHero(
                profile: _profile,
                isSignedIn: widget.isSignedIn,
                onConnect: () => _gatedAction('connect'),
                onChat: _chat,
                onMore: () => _notice('More options — coming soon.'),
              ),
            ),
            if (!widget.isSignedIn)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Text(
                    'This page is public. Sign in to connect or start a '
                    'direct message.',
                    style: DiscoveryText.publicNote,
                  ),
                ),
              ),
            // The endpoint says whether they are verified but not why not,
            // so an unverified provider carries the pill and no explainer
            // rather than one written here.
            if (!_profile.verified)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _BadgeNote(
                    note: 'This provider has not been verified by ServiQ.',
                  ),
                ),
              ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsHeader(
                child: ColoredBox(
                  color: AppColor.white,
                  child: ProviderSegmentedTabs(
                    current: state.tab,
                    onSelect: _selectTab,
                  ),
                ),
              ),
            ),
            ..._body(state, data),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        current: DiscoveryTab.explore,
        onSelect: (tab) => widget.onTabSelected?.call(tab),
        onPost: widget.onPost,
        // The store grid shows its own count, so it has to be told when
        // the cart is emptied from the bar.
        onCartChanged: () => _bloc.add(const ProviderCartRefreshed()),
      ),
    );
  }

  List<Widget> _body(ProviderState state, ProviderProfileState data) {
    return switch (state.tab) {
      ProviderTab.services => _servicesBody(state, data),
      ProviderTab.store => _storeBody(state, data),
      ProviderTab.reviews => _reviewsBody(data),
      ProviderTab.about => _aboutBody(state, data),
    };
  }

  /// The shape a tab wears while its endpoint answers. Never a spinner: the
  /// section wears what it is about to become.
  List<Widget> _tabSkeleton(String caption) => [
    SliverToBoxAdapter(
      child: SizedBox(
        height: 340,
        child: SkeletonList(caption: caption, rows: 3),
      ),
    ),
  ];

  /// What went wrong on one tab, and the way out of it. Only the tab is
  /// taken over — the rest of the provider is still perfectly readable.
  List<Widget> _tabError({
    required Failure failure,
    required String title,
    required VoidCallback onRetry,
  }) {
    final isOffline = ProviderProfileState.isOffline(failure);

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ErrorState(
            isOffline: isOffline,
            title: isOffline ? 'You are offline' : title,
            body: isOffline
                ? 'Nothing loaded because there is no connection.'
                : 'Something went wrong on our side, not yours.',
            onRetry: onRetry,
            reference: isOffline ? null : failure.errorCode,
          ),
        ),
      ),
    ];
  }

  List<Widget> _servicesBody(ProviderState state, ProviderProfileState data) {
    if (data.isLoadingServices && !data.servicesLoaded) {
      return _tabSkeleton('Loading services');
    }
    if (data.servicesFailure != null && data.services.isEmpty) {
      return _tabError(
        failure: data.servicesFailure!,
        title: "Couldn't load their services",
        onRetry: () => _profileBloc.add(const ProviderServicesRequested()),
      );
    }
    if (data.servicesAreEmpty) {
      return [const _Note('This provider lists no services.')];
    }

    final services = data.offeredServices;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            '${services.length} '
            '${services.length == 1 ? 'service' : 'services'}',
            style: DiscoveryText.footnote,
          ),
        ),
      ),
      SliverList.separated(
        // Keyed on the tab so switching sections builds the list afresh and
        // its cards play their entrance, rather than the new section's
        // content appearing inside the old one's rows.
        key: ValueKey(state.tab),
        itemCount: services.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final service = services[index].asDisplay;
          return FadeSlideIn(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ServiceCard(
                service: service,
                isOnVisit: state.isOnVisit(service.name),
                onBook: widget.isSignedIn
                    ? () => _addToVisit(service)
                    : () => _gatedAction('book ${service.name}'),
                onRemove: () => _bloc.add(ProviderServiceRemoved(service.name)),
              ),
            ),
          );
        },
      ),
    ];
  }

  List<Widget> _storeBody(ProviderState state, ProviderProfileState data) {
    if (data.isLoadingProducts && !data.productsLoaded) {
      return _tabSkeleton('Loading their store');
    }
    if (data.productsFailure != null && data.products.isEmpty) {
      return _tabError(
        failure: data.productsFailure!,
        title: "Couldn't load their store",
        onRetry: () => _profileBloc.add(const ProviderProductsRequested()),
      );
    }
    if (data.productsAreEmpty) {
      return [const _Note('This provider sells no parts.')];
    }

    final products = data.offeredProducts;

    // Only the cart this provider's parts are in — a cart belongs to one
    // provider, so another store's count would be a number about somebody
    // else.
    final cartCount = state.cart?.partCount ?? 0;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Text(
                '${products.length} '
                '${products.length == 1 ? 'product' : 'products'}',
                style: DiscoveryText.footnoteStrong,
              ),
              const Spacer(),
              if (cartCount > 0)
                PressableScale(
                  onTap: _openCart,
                  pressedScale: 0.92,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColor.providerChipFill,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$cartCount in cart',
                      style: DiscoveryText.addChip,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid.builder(
          key: ValueKey(state.tab),
          itemCount: products.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 196,
          ),
          itemBuilder: (context, index) {
            final product = products[index].asDisplay;
            return FadeSlideIn(
              index: index,
              child: ProductCard(
                product: product,
                quantityInCart: state.quantityOf(product.name),
                onTap: () => _openProduct(product),
                onAdd: widget.isSignedIn
                    ? () => _openProduct(product)
                    : () => _gatedAction('add ${product.name}'),
                onIncrement: () =>
                    _bloc.add(ProviderPartStepped(name: product.name, delta: 1)),
                onDecrement: () => _bloc.add(
                  ProviderPartStepped(name: product.name, delta: -1),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _reviewsBody(ProviderProfileState data) {
    final rating = _profile.rating;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: RatingSummaryCard(
            rating: rating.average,
            reviewCount: rating.total,
            // Five stars down to one, as the card draws them, from the
            // counts the endpoint keys by star.
            breakdown: [
              for (var star = 5; star >= 1; star--) rating.shareAt(star),
            ],
          ),
        ),
      ),
      if (data.isLoadingReviews && !data.reviewsLoaded)
        ..._tabSkeleton('Loading reviews')
      else if (data.reviewsFailure != null && data.reviews.isEmpty)
        ..._tabError(
          failure: data.reviewsFailure!,
          title: "Couldn't load their reviews",
          onRetry: () => _profileBloc.add(const ProviderReviewsRequested()),
        )
      else if (data.reviewsAreEmpty)
        const _Note('No reviews yet.'),
    ];
  }

  List<Widget> _aboutBody(ProviderState state, ProviderProfileState data) {
    final about = _profile.about?.trim() ?? '';
    final address = _profile.addressBlock;
    final coverage = _profile.coverageBlock;

    return [
      SliverToBoxAdapter(
        key: ValueKey(state.tab),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left out rather than written for them when they have said
              // nothing about themselves.
              if (about.isNotEmpty) ...[
                FadeSlideIn(child: Text(about, style: DiscoveryText.body)),
                const SizedBox(height: 20),
              ],
              FadeSlideIn(
                index: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (address.isNotEmpty)
                      _Field(label: 'ADDRESS', value: address),
                    _hoursField(data),
                    if (coverage.isNotEmpty)
                      _Field(label: 'SERVES', value: coverage, isLast: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// The week's hours, with the three states its own endpoint can be in.
  Widget _hoursField(ProviderProfileState data) {
    if (data.isLoadingAvailability && !data.availabilityLoaded) {
      return const _Field(label: 'HOURS', value: 'Loading…');
    }
    if (data.availabilityFailure != null && data.availability.isEmpty) {
      return _FieldAction(
        label: 'HOURS',
        value: "Couldn't load their hours.",
        actionLabel: 'Try again',
        onAction: () =>
            _profileBloc.add(const ProviderAvailabilityRequested()),
      );
    }
    if (data.availabilityIsEmpty) {
      return const _Field(label: 'HOURS', value: 'No hours listed.');
    }
    return _Field(label: 'HOURS', value: data.availability.hoursBlock);
  }
}

/// Wraps the flow's empty-state note as a sliver.
class _Note extends StatelessWidget {
  const _Note(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DiscoveryNote(message),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value, this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: DiscoveryText.fieldLabel),
        const SizedBox(height: 6),
        Text(value, style: DiscoveryText.fieldValue),
        if (!isLast) ...[
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColor.discoveryBorder,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _BadgeNote extends StatelessWidget {
  const _BadgeNote({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13.2),
      decoration: BoxDecoration(
        color: AppColor.providerNoteFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColor.discoveryBorder, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('No verified badge', style: DiscoveryText.noteTitle),
          const SizedBox(height: 6),
          Text(note, style: DiscoveryText.noteBody),
        ],
      ),
    );
  }
}

/// Keeps the tab strip on screen once the head has scrolled past.
class _TabsHeader extends SliverPersistentHeaderDelegate {
  const _TabsHeader({required this.child});

  final Widget child;

  @override
  double get minExtent => 46;

  @override
  double get maxExtent => 46;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      child;

  @override
  bool shouldRebuild(_TabsHeader oldDelegate) => oldDelegate.child != child;
}

/// The page before the provider has arrived.
class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColor.white,
      body: SafeArea(
        child: SkeletonList(caption: 'Loading this provider', hasHeader: true),
      ),
    );
  }
}

/// The page when the provider could not be loaded at all.
class _ProfileError extends StatelessWidget {
  const _ProfileError({required this.state, required this.onRetry});

  final ProviderProfileState state;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = state.failure;
    final isOffline = ProviderProfileState.isOffline(failure);
    // A slug nobody answers to is not a fault to apologise for — it is a
    // provider who is not there, and saying so is the honest answer.
    final isMissing = state.isNotFound;

    return Scaffold(
      backgroundColor: AppColor.white,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 20, 0),
              child: Row(children: [AppBackButton()]),
            ),
            Expanded(
              child: ErrorState(
                isOffline: isOffline,
                title: isMissing
                    ? 'That provider is not here'
                    : isOffline
                    ? 'You are offline'
                    : "Couldn't load this provider",
                body: isMissing
                    ? 'They may have closed, or the link may be out of date.'
                    : isOffline
                    ? 'Nothing loaded because there is no connection. They '
                          'will be here when you are back.'
                    : 'Something went wrong on our side, not yours.',
                onRetry: onRetry,
                reference: isOffline || isMissing ? null : failure?.errorCode,
                occurredAt: isOffline ? null : state.failedAt,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A field whose value could not be loaded, with the way to try again.
class _FieldAction extends StatelessWidget {
  const _FieldAction({
    required this.label,
    required this.value,
    required this.actionLabel,
    required this.onAction,
  });

  final String label;
  final String value;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: DiscoveryText.fieldLabel),
          const SizedBox(height: 6),
          Text(value, style: DiscoveryText.body),
          const SizedBox(height: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onAction,
            child: Text(actionLabel, style: DiscoveryText.inlineLink),
          ),
        ],
      ),
    );
  }
}
