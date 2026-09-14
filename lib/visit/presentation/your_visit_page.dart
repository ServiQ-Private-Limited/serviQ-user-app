import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:local_markerplace/components/art/seeded_artwork.dart';
import 'package:local_markerplace/visit/bloc/visit_bloc.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_header.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/visit/model/visit.dart';
import 'package:local_markerplace/visit/model/visit_mode.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/presentation/components/cart_bits.dart';
import 'package:local_markerplace/visit/presentation/components/slot_sheet.dart';
import 'package:local_markerplace/visit/presentation/components/visit_bits.dart';
import 'package:local_markerplace/visit/presentation/confirm_visit_page.dart';
import 'package:local_markerplace/me/presentation/choose_address_sheet.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

/// My Cart — everything the seeker has put aside, and how it gets timed.
///
/// One screen in several states rather than a screen per mode: the booking
/// being reviewed does not change when the timing does, so the services, the
/// address and the bill stay put and only the middle of the page answers the
/// tab at the top.
class YourVisitPage extends StatelessWidget {
  const YourVisitPage({
    super.key,
    required this.providerName,
    this.repository,
    this.localityName,
    this.onAddAnother,
  });

  /// Whose cart this is. There is one per provider, so a cart screen without
  /// a provider would not know which to show.
  final String providerName;

  final VisitRepository? repository;

  /// The area a newly added address is filed under.
  final String? localityName;

  /// Sends the seeker back to the provider's services. Null where there is
  /// nowhere obvious to go, and then the link is left off.
  final VoidCallback? onAddAnother;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          VisitBloc(visitRepository: repository ?? VisitRepository.shared)
            ..add(CartOpened(providerName)),
      child: _YourVisitView(
        onAddAnother: onAddAnother,
        localityName: localityName,
      ),
    );
  }
}

class _YourVisitView extends StatefulWidget {
  const _YourVisitView({
    required this.onAddAnother,
    required this.localityName,
  });

  final VoidCallback? onAddAnother;

  /// The area a newly added address is filed under.
  final String? localityName;

  @override
  State<_YourVisitView> createState() => _YourVisitViewState();
}

class _YourVisitViewState extends State<_YourVisitView> {
  VisitBloc get _bloc => context.read<VisitBloc>();

  VisitState get _state => _bloc.state;

  void _selectTab(VisitMode mode) => _bloc.add(CartModeSelected(mode));

  Future<void> _pickSlot() async {
    final bloc = _bloc;
    final chosen = await showSlotSheet(
      context,
      days: bloc.state.days,
      selected: bloc.state.cart?.slot,
    );
    if (chosen == null) return;
    bloc.add(CartSlotChosen(chosen));
  }

  Future<void> _continue() async {
    final state = _state;
    final visit = state.cart;
    if (visit == null) return;
    if (state.isInstantBlocked) return _selectTab(VisitMode.scheduled);
    if (state.needsSlot) return _pickSlot();
    if (!visit.isReady) {
      // Unreachable while the tab and the mode agree, but a button that
      // silently does nothing is worse than one that says what is missing.
      return _notice('Choose when you need this first.');
    }

    final bloc = _bloc;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfirmVisitPage(
          localityName: widget.localityName,
          providerName: state.providerName,
          repository: bloc.visitRepository,
        ),
      ),
    );
    // Confirming empties the cart, so what is left is read again.
    bloc.add(const CartRefreshed());
  }

  /// Picks a different saved address for this cart.
  ///
  /// The sheet also offers adding one, which is the way out for a seeker who
  /// has none — the row they tapped says so, and this is what it leads to.
  Future<void> _changeAddress() async {
    final bloc = _bloc;
    final chosen = await chooseAddress(
      context,
      localityName: widget.localityName,
      currentId: _state.cart?.addressId,
    );
    if (chosen == null) return;
    bloc.add(CartAddressChosen(chosen));
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
    final visit = context.watch<VisitBloc>().state.cart;

    return Scaffold(
      backgroundColor: AppColor.discoveryTint,
      body: SafeArea(
        bottom: false,
        child: visit == null ? const _EmptyCart() : _cart(visit),
      ),
      bottomNavigationBar: visit == null ? null : _actionBar(visit),
    );
  }

  Widget _cart(Visit visit) {
    return Column(
      children: [
        DiscoveryHeader(title: 'My Cart', subtitle: visit.providerName),
        const SizedBox(height: 14),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CartModeTabs(
                  selected: _state.tab,
                  onSelect: _selectTab,
                  disabled: {if (!_state.instantAvailable) VisitMode.instant},
                ),
                const SizedBox(height: 22),
                CartSectionHeading(
                  title: 'Review booking',
                  trailing: visit.contentLine,
                ),
                _reviewCard(visit),
                const SizedBox(height: 16),
                CartCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 18,
                  ),
                  onTap: () => _notice('Coupons — coming soon.'),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'View all coupons',
                          style: DiscoveryText.rowTitle.copyWith(fontSize: 15),
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: AppColor.discoveryTextTertiary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const CartSectionHeading(title: 'Booking details'),
                _detailsCard(visit),
                const SizedBox(height: 22),
                const CartSectionHeading(title: 'Bill details'),
                _billCard(visit),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _reviewCard(Visit visit) {
    return CartCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, service) in visit.services.indexed) ...[
            if (index > 0) const CartDivider(),
            _LineRow(
              name: service.name,
              note: service.note,
              unitPrice: service.unitPrice,
              quantity: service.quantity,
              unitLabel: service.quantity == 1 ? 'Unit' : 'Units',
              onQuantity: (value) => _bloc.add(
                ServiceQuantityChanged(index: index, quantity: value),
              ),
            ),
          ],
          // Parts sit under the services in the same list: the seeker is
          // buying one basket from one provider, not filling two.
          for (final (index, part) in visit.parts.indexed) ...[
            if (index > 0 || visit.services.isNotEmpty) const CartDivider(),
            _LineRow(
              name: part.name,
              note: '',
              unitPrice: part.unitPrice,
              quantity: part.quantity,
              unitLabel: part.quantity == 1 ? 'Piece' : 'Pieces',
              onQuantity: (value) =>
                  _bloc.add(PartQuantityChanged(index: index, quantity: value)),
            ),
          ],
          if (_state.tab != VisitMode.instant && visit.services.isNotEmpty) ...[
            const SizedBox(height: 14),
            const CartNote(
              text:
                  'Slots may vary based on partner availability and the '
                  'selected service.',
            ),
          ],
          const CartDivider(),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                Text('Missed something? ', style: DiscoveryText.caption),
                PressableScale(
                  onTap:
                      widget.onAddAnother ??
                      () => _notice('Browse a provider to add more.'),
                  pressedScale: 0.94,
                  child: Text(
                    'Add more services.',
                    style: DiscoveryText.link.copyWith(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard(Visit visit) {
    final scheduledFor = visit.scheduledForLabel;

    return CartCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_state.tab == VisitMode.instant)
            CartDetailRow(
              icon: Icons.bolt_rounded,
              title: 'As soon as a provider accepts',
              subtitle: _state.instantAvailable
                  ? 'Usually about 40 minutes · adds ₹99'
                  : 'Not available right now',
            )
          else if (scheduledFor == null)
            CartDetailRow(
              icon: Icons.calendar_today_rounded,
              title: 'No time chosen yet',
              subtitle: 'Pick when the work should start',
              link: 'Select slot',
              onLinkTap: _pickSlot,
            )
          else
            CartDetailRow(
              icon: Icons.calendar_today_rounded,
              title: 'Scheduled for',
              subtitle: scheduledFor,
              link: 'Change slot',
              onLinkTap: _pickSlot,
            ),
          const CartDivider(),
          CartDetailRow(
            icon: Icons.place_outlined,
            title: 'Location',
            subtitle: visit.addressSubtitle,
            onTap: _changeAddress,
          ),
          const CartDivider(),
          CartDetailRow(
            icon: Icons.phone_outlined,
            title: visit.contactName,
            subtitle: visit.contactPhone,
            onTap: () => _notice('Changing the contact — coming soon.'),
          ),
        ],
      ),
    );
  }

  Widget _billCard(Visit visit) {
    return CartCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (visit.servicesTotal > 0)
            _BillRow(label: 'Services', value: rupees(visit.servicesTotal)),
          if (visit.partsTotal > 0)
            _BillRow(label: 'Parts', value: rupees(visit.partsTotal)),
          if (visit.instantFee > 0)
            _BillRow(label: 'Instant fee', value: rupees(visit.instantFee)),
          const _BillRow(label: 'Visit charge', value: 'waived'),
          const CartDivider(top: 12, bottom: 12),
          _BillRow(label: 'Total', value: rupees(_total(visit)), isTotal: true),
          const SizedBox(height: 8),
          Text(
            visit.parts.isEmpty
                ? 'Pay after the work is done. The provider confirms the '
                      'final price before starting.'
                : 'The provider brings the parts on the visit. Pay once the '
                      'work is done.',
            style: DiscoveryText.fine,
          ),
        ],
      ),
    );
  }

  /// The bill follows the tab, not the visit — a seeker reading the Instant
  /// tab should see the ₹99 before they commit to it.
  double _total(Visit visit) =>
      visit.servicesTotal +
      visit.partsTotal +
      (_state.tab == VisitMode.instant ? VisitMode.instant.fee : 0);

  Widget _actionBar(Visit visit) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: AppColor.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_state.isInstantBlocked) ...[
              const _InstantUnavailable(),
              const SizedBox(height: 12),
            ],
            VisitCta(
              label: _ctaLabel(visit),
              leading:
                  _state.tab == VisitMode.instant && !_state.isInstantBlocked
                  ? const Icon(
                      Icons.bolt_rounded,
                      size: 20,
                      color: AppColor.white,
                    )
                  : null,
              onTap: _continue,
            ),
          ],
        ),
      ),
    );
  }

  String _ctaLabel(Visit visit) {
    if (_state.isInstantBlocked) return 'Schedule now';
    if (_state.needsSlot) return 'Select time slot';
    return 'Confirm booking · ${rupees(_total(visit))}';
  }
}

/// One line in the review card — a service or a part. They are drawn the
/// same because the seeker is looking at one cart, and only the unit under
/// the stepper says which is which.
class _LineRow extends StatelessWidget {
  const _LineRow({
    required this.name,
    required this.note,
    required this.unitPrice,
    required this.quantity,
    required this.unitLabel,
    required this.onQuantity,
  });

  final String name;
  final String note;
  final double unitPrice;
  final int quantity;
  final String unitLabel;
  final ValueChanged<int> onQuantity;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: SeededArtwork(
                seed: name,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: DiscoveryText.rowTitle.copyWith(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(rupees(unitPrice), style: DiscoveryText.offerName),
            ),
            const SizedBox(width: 12),
            CartQuantityStepper(
              value: quantity,
              unitLabel: unitLabel,
              // Stepping the last one off empties the line, which is the
              // only way to take something out of the cart from here.
              minimum: 0,
              onChanged: onQuantity,
            ),
          ],
        ),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: DiscoveryText.smallPrint.copyWith(
              color: AppColor.discoveryTextTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _BillRow extends StatelessWidget {
  const _BillRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: isTotal
                  ? DiscoveryText.rowTitle.copyWith(fontSize: 14)
                  : DiscoveryText.caption,
            ),
          ),
          Text(
            value,
            style: isTotal ? DiscoveryText.visitTotal : DiscoveryText.chip,
          ),
        ],
      ),
    );
  }
}

/// Why the Instant tab cannot be taken, said where the button would act.
class _InstantUnavailable extends StatelessWidget {
  const _InstantUnavailable();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColor.visitEtaTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.event_busy_rounded,
            size: 22,
            color: AppColor.discoveryGradientEnd,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Instant currently unavailable',
                  style: DiscoveryText.groupHeading.copyWith(
                    color: AppColor.discoveryGradientEnd,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Instant bookings can’t be placed at this time. Please try '
                  'again later.',
                  style: DiscoveryText.meta.copyWith(
                    height: 16 / 11.5,
                    color: AppColor.discoveryGradientStart,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nothing added yet — reached by coming back after removing the last one.
class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const DiscoveryHeader(title: 'My Cart'),
        const SizedBox(height: 14),
        const Divider(height: 1, thickness: 1, color: AppColor.discoveryBorder),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Nothing in your cart yet. Add a service or a part from a '
                'provider to start one.',
                textAlign: TextAlign.center,
                style: DiscoveryText.footnoteStrong.copyWith(height: 18 / 12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
