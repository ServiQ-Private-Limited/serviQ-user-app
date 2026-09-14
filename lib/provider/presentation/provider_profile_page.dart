import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_markerplace/basket/app_bottom_bar.dart';
import 'package:local_markerplace/provider/bloc/provider_bloc.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_note.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_tab_bar.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/provider/model/provider_profile.dart';
import 'package:local_markerplace/provider/model/provider_service.dart';
import 'package:local_markerplace/provider/model/store_product.dart';
import 'package:local_markerplace/provider/presentation/components/map_thumbnail.dart';
import 'package:local_markerplace/provider/presentation/components/product_card.dart';
import 'package:local_markerplace/provider/presentation/components/provider_hero.dart';
import 'package:local_markerplace/provider/presentation/components/rating_summary.dart';
import 'package:local_markerplace/provider/presentation/components/review_row.dart';
import 'package:local_markerplace/provider/presentation/components/segmented_tabs.dart';
import 'package:local_markerplace/provider/presentation/components/service_rows.dart';
import 'package:local_markerplace/provider/repository/provider_repository.dart';
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
    required this.providerName,
    this.isSignedIn = true,
    this.initialTab = ProviderTab.services,
    this.localityName = 'Ajnara Gen X',
    this.repository = const ProviderRepository(),
    this.onTabSelected,
    this.onPost,
  });

  final String providerName;
  final bool isSignedIn;
  final ProviderTab initialTab;

  /// The seeker's own area, which the store's free-delivery line names.
  final String localityName;
  final ProviderRepository repository;
  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ProviderBloc(
            providerRepository: repository,
            visitRepository: VisitRepository.shared,
          )..add(
            ProviderRequested(
              providerName: providerName,
              localityName: localityName,
              initialTab: initialTab,
            ),
          ),
      child: _ProviderProfileView(
        isSignedIn: isSignedIn,
        onTabSelected: onTabSelected,
        onPost: onPost,
      ),
    );
  }
}

class _ProviderProfileView extends StatefulWidget {
  const _ProviderProfileView({
    required this.isSignedIn,
    required this.onTabSelected,
    required this.onPost,
  });

  final bool isSignedIn;
  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;

  @override
  State<_ProviderProfileView> createState() => _ProviderProfileViewState();
}

class _ProviderProfileViewState extends State<_ProviderProfileView> {
  ProviderBloc get _bloc => context.read<ProviderBloc>();

  ProviderProfile get _profile => _bloc.state.profile!;

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
    final match = _profile.services.where((s) => s.name == serviceName);
    if (match.isEmpty) return;
    _addToVisit(match.first);
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
    final state = context.watch<ProviderBloc>().state;
    if (state.profile == null) {
      return const Scaffold(backgroundColor: AppColor.white);
    }

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
                onChat: () => _gatedAction('chat'),
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
            if (_profile.badgeNote != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: _BadgeNote(note: _profile.badgeNote!),
                ),
              ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsHeader(
                child: ColoredBox(
                  color: AppColor.white,
                  child: ProviderSegmentedTabs(
                    current: state.tab,
                    onSelect: (tab) => _bloc.add(ProviderTabSelected(tab)),
                  ),
                ),
              ),
            ),
            ..._body(state),
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

  List<Widget> _body(ProviderState state) {
    return switch (state.tab) {
      ProviderTab.services => _servicesBody(state),
      ProviderTab.store => _storeBody(state),
      ProviderTab.reviews => _reviewsBody(state),
      ProviderTab.about => _aboutBody(state),
    };
  }

  List<Widget> _servicesBody(ProviderState state) {
    final services = _profile.services;
    if (services.isEmpty) {
      return [const _Note('No services listed yet — coming soon.')];
    }

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
        itemBuilder: (context, index) => FadeSlideIn(
          index: index,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ServiceCard(
              service: services[index],
              isOnVisit: state.isOnVisit(services[index].name),
              onBook: widget.isSignedIn
                  ? () => _addToVisit(services[index])
                  : () => _gatedAction('book ${services[index].name}'),
              onRemove: () =>
                  _bloc.add(ProviderServiceRemoved(services[index].name)),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _storeBody(ProviderState state) {
    final products = _profile.products;
    if (products.isEmpty) {
      return [const _Note('No products listed yet — coming soon.')];
    }

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
                '${products.length} products',
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
          itemBuilder: (context, index) => FadeSlideIn(
            index: index,
            child: ProductCard(
              product: products[index],
              quantityInCart: state.quantityOf(products[index].name),
              onTap: () => _openProduct(products[index]),
              onAdd: widget.isSignedIn
                  ? () => _openProduct(products[index])
                  : () => _gatedAction('add ${products[index].name}'),
              onIncrement: () => _bloc.add(
                ProviderPartStepped(name: products[index].name, delta: 1),
              ),
              onDecrement: () => _bloc.add(
                ProviderPartStepped(name: products[index].name, delta: -1),
              ),
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _reviewsBody(ProviderState state) {
    final reviews = _profile.reviews;

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: RatingSummaryCard(
            rating: _profile.rating,
            reviewCount: _profile.reviewCount,
            breakdown: _profile.ratingBreakdown,
          ),
        ),
      ),
      if (reviews.isEmpty)
        const _Note('No reviews yet.')
      else
        SliverList.separated(
          key: ValueKey(state.tab),
          itemCount: reviews.length,
          separatorBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColor.discoveryBorder,
            ),
          ),
          itemBuilder: (context, index) => FadeSlideIn(
            index: index,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, index == 0 ? 22 : 0, 20, 0),
              child: ReviewRow(review: reviews[index]),
            ),
          ),
        ),
    ];
  }

  List<Widget> _aboutBody(ProviderState state) {
    return [
      SliverToBoxAdapter(
        key: ValueKey(state.tab),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeSlideIn(
                child: Text(_profile.about, style: DiscoveryText.body),
              ),
              const SizedBox(height: 20),
              FadeSlideIn(
                index: 1,
                child: MapThumbnail(onTap: () => _notice('Map — coming soon.')),
              ),
              const SizedBox(height: 22),
              FadeSlideIn(
                index: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Field(label: 'ADDRESS', value: _profile.address),
                    _Field(label: 'HOURS', value: _profile.hours),
                    _Field(
                      label: 'SERVES',
                      value: _profile.serves,
                      isLast: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
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
