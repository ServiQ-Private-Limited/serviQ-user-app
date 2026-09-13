import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_markerplace/discovery/bloc/catalogue_bloc.dart';

import 'package:local_markerplace/components/art/seeded_artwork.dart';
import 'package:local_markerplace/components/motion/app_motion.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/basket/basket.dart';
import 'package:local_markerplace/discovery/model/catalogue_service.dart';
import 'package:local_markerplace/discovery/model/service_category.dart';
import 'package:local_markerplace/discovery/presentation/components/category_filter_sheet.dart';
import 'package:local_markerplace/discovery/presentation/components/filter_button.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_header.dart';
import 'package:local_markerplace/discovery/presentation/components/pending_booking_bar.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/discovery/presentation/components/provider_avatar.dart';
import 'package:local_markerplace/discovery/repository/discovery_repository.dart';
import 'package:local_markerplace/provider/repository/provider_repository.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/presentation/add_to_visit_sheet.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

/// Everything bookable in the seeker's area, in one list.
///
/// Home's category tiles are a way into this rather than six separate
/// screens: the catalogue is flat and a chip narrows it, so "See all" and a
/// tap on "Plumber" land in the same place with a different chip lit.
///
/// Adding here puts the job on the visit, which is where a service lives —
/// a part goes in the cart, a service becomes a trip.
class ServicesPage extends StatelessWidget {
  const ServicesPage({
    super.key,
    required this.localityName,
    this.initialCategory,
    this.categories,
    this.repository = const DiscoveryRepository(),
    this.providers = const ProviderRepository(),
    this.visits,
  });

  final String localityName;

  /// The tile that was tapped, or null for "See all".
  final String? initialCategory;

  /// The trades to offer as filters — home's, which came from the endpoint,
  /// so the sheet lists what the seeker just saw rather than a second set of
  /// its own. Null falls back to the seeded catalogue's categories, which is
  /// what a screen opened outside that flow gets.
  final List<ServiceCategory>? categories;

  final DiscoveryRepository repository;

  /// Where the catalogue comes from: each provider's own service list, so
  /// the prices here are the prices on their page.
  final ProviderRepository providers;

  final VisitRepository? visits;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          CatalogueBloc(
            providerRepository: providers,
            visitRepository: visits ?? VisitRepository.shared,
          )..add(
            CatalogueOpened(
              localityName: localityName,
              category: initialCategory,
              categories: categories ?? repository.categories(),
            ),
          ),
      child: _ServicesView(visits: visits),
    );
  }
}

class _ServicesView extends StatefulWidget {
  const _ServicesView({required this.visits});

  final VisitRepository? visits;

  @override
  State<_ServicesView> createState() => _ServicesViewState();
}

class _ServicesViewState extends State<_ServicesView> {
  CatalogueBloc get _bloc => context.read<CatalogueBloc>();

  /// True while the sheet is up.
  ///
  /// A second tap on the icon would otherwise stack a second sheet on the
  /// first, and choosing in one would leave the other still standing.
  bool _filterIsOpen = false;

  /// Opens the full list of trades. Dismissing it changes nothing, which is
  /// why a null answer is not read as "All".
  Future<void> _openFilter() async {
    if (_filterIsOpen) return;
    _filterIsOpen = true;
    final bloc = _bloc;
    final choice = await CategoryFilterSheet.show(
      context,
      categories: bloc.state.categories,
      selected: bloc.state.category,
    );
    _filterIsOpen = false;
    if (choice == null) return;
    bloc.add(CatalogueFiltered(choice.label));
  }

  Future<void> _add(CatalogueService service) async {
    final bloc = _bloc;
    final added = await showAddToVisitSheet(
      context,
      name: service.name,
      detail: service.detail,
      unitPrice: rupeesFrom(service.fromPrice),
    );
    if (added == null) return;

    bloc.add(
      CatalogueServiceAdded(
        providerName: service.providerName,
        providerLine: service.providerLine(bloc.state.localityName),
        isVerifiedProvider: service.isVerifiedProvider,
        service: added,
      ),
    );
  }

  Future<void> _openVisit() async {
    await openBasket(context, visits: widget.visits);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CatalogueBloc>().state;
    final services = state.services;
    final cart = currentBasket(visits: widget.visits);

    return Scaffold(
      backgroundColor: AppColor.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DiscoveryHeader(
              title: 'Services',
              subtitle: [
                '${services.length} '
                    '${services.length == 1 ? 'job' : 'jobs'} in '
                    '${state.localityName}',
                // Says which filter produced that count, so a short list
                // reads as narrowed rather than as an empty area.
                ?state.category,
              ].join(' · '),
              trailing: FilterButton(
                isFiltered: state.category != null,
                onTap: _openFilter,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColor.discoveryBorder,
            ),
            Expanded(
              child: services.isEmpty
                  ? const _NoServices()
                  : ListView.separated(
                      // Keyed on the filter so switching categories builds
                      // the list afresh and its rows play their entrance.
                      key: ValueKey(state.category),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                      itemCount: services.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => FadeSlideIn(
                        index: index,
                        child: CatalogueServiceCard(
                          service: services[index],
                          quantityOnVisit: state.quantityOf(services[index]),
                          onAdd: () => _add(services[index]),
                          onRemove: () => _bloc.add(
                            CatalogueServiceRemoved(
                              providerName: services[index].providerName,
                              name: services[index].name,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: cart == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: PendingBookingBar(booking: cart, onView: _openVisit),
              ),
            ),
    );
  }
}

/// One job in the catalogue: what it is, who does it, and the way on or off
/// the visit.
class CatalogueServiceCard extends StatelessWidget {
  const CatalogueServiceCard({
    super.key,
    required this.service,
    required this.quantityOnVisit,
    required this.onAdd,
    required this.onRemove,
  });

  final CatalogueService service;

  /// Zero when the job is not on the visit; the count when it is, which is
  /// what turns Add into a way to take it off.
  final int quantityOnVisit;

  final VoidCallback onAdd;
  final VoidCallback onRemove;

  bool get _isOnVisit => quantityOnVisit > 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.quick,
      curve: AppMotion.emphasized,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isOnVisit
              ? AppColor.discoveryAccent
              : AppColor.discoveryBorder,
          width: _isOnVisit ? 2 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColor.discoveryShadow.withValues(alpha: 0.05),
            blurRadius: 7,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            height: 56,
            child: SeededArtwork(
              seed: service.name,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        service.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DiscoveryText.offerName,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(service.fromPrice, style: DiscoveryText.fromPrice),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  service.detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DiscoveryText.smallPrint,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ProviderAvatar(
                      initials: _initials(service.providerName),
                      seed: service.providerName,
                      size: 22,
                      isVerified: service.isVerifiedProvider,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        service.providerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: DiscoveryText.meta,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.star_rounded,
                      size: 13,
                      color: AppColor.discoveryStar,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      service.rating.toStringAsFixed(1),
                      style: DiscoveryText.meta,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  // A service is one job, not a quantity to step through, so
                  // once it is on the visit the row offers to take it off
                  // rather than to add another.
                  child: _isOnVisit
                      ? _RemoveButton(onTap: onRemove)
                      : _AddButton(onTap: onAdd),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.9,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: AppColor.providerChipFill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text('Add', style: DiscoveryText.addChip),
      ),
    );
  }
}

/// "In cart", with the bin that takes it back out.
class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'In cart',
          style: DiscoveryText.addChip.copyWith(
            color: AppColor.discoveryLiveText,
          ),
        ),
        const SizedBox(width: 8),
        PressableScale(
          onTap: onTap,
          pressedScale: 0.85,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColor.stockLowTint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColor.authError,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoServices extends StatelessWidget {
  const _NoServices();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Text(
        'Nothing listed under this category yet. Post what you need and '
        'providers will answer.',
        textAlign: TextAlign.center,
        style: DiscoveryText.footnoteStrong.copyWith(height: 18 / 12),
      ),
    ),
  );
}

String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}
