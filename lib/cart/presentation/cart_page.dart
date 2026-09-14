import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_markerplace/cart/bloc/cart_bloc.dart';
import 'package:local_markerplace/cart/model/cart_bill.dart';
import 'package:local_markerplace/cart/model/cart_booking_mode.dart';
import 'package:local_markerplace/cart/model/cart_item.dart';
import 'package:local_markerplace/cart/presentation/components/bill_details_card.dart';
import 'package:local_markerplace/cart/presentation/components/booking_details_card.dart';
import 'package:local_markerplace/cart/presentation/components/booking_mode_tabs.dart';
import 'package:local_markerplace/cart/presentation/components/cart_card.dart';
import 'package:local_markerplace/cart/presentation/components/cart_shimmer.dart';
import 'package:local_markerplace/cart/presentation/components/mode_unavailable_banner.dart';
import 'package:local_markerplace/cart/presentation/components/review_booking_card.dart';
import 'package:local_markerplace/cart/presentation/components/time_slot_sheet.dart';
import 'package:local_markerplace/cart/repository/cart_repository.dart';
import 'package:local_markerplace/me/presentation/choose_address_sheet.dart';
import 'package:local_markerplace/components/primary_button.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/dashboard/model/services.dart';

/// "My Cart": the services the customer picked, how they want them delivered,
/// and what it costs.
class CartPage extends StatelessWidget {
  const CartPage({super.key, this.services = const [], this.localityName});

  /// Services selected on the dashboard. Empty on a deep link, which simply
  /// yields an empty cart.
  final List<ServiceDetails> services;

  /// The area a newly added address is filed under.
  final String? localityName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CartBloc(cartRepository: const CartRepository()),
      child: _CartView(services: services, localityName: localityName),
    );
  }
}

class _CartView extends StatefulWidget {
  const _CartView({required this.services, this.localityName});

  final List<ServiceDetails> services;

  /// The area a newly added address is filed under.
  final String? localityName;

  @override
  State<_CartView> createState() => _CartViewState();
}

class _CartViewState extends State<_CartView> {
  @override
  void initState() {
    context.read<CartBloc>().add(OnFetchCart(widget.services));
    super.initState();
  }

  /// Placeholder for the parts of checkout that have no backend yet, so a tap
  /// says what will happen instead of doing nothing.
  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Drops a service from the cart. The line disappearing and the bill
  /// dropping are the confirmation, so nothing is announced on top of that.
  void _removeItem(CartItem item) {
    HapticFeedback.mediumImpact();
    context.read<CartBloc>().add(OnRemoveItem(item.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.neutralGreyColor50,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColor.white,
        surfaceTintColor: AppColor.white,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded),
              color: AppColor.neutralGreyColor800,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 4),
            const Text(
              'My Cart',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColor.neutralGreyColor800,
              ),
            ),
          ],
        ),
      ),
      body: BlocConsumer<CartBloc, CartState>(
        listenWhen: (previous, current) =>
            current.errorMessage.isNotEmpty &&
            previous.errorMessage != current.errorMessage,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(state.errorMessage)));
          context.read<CartBloc>().add(const OnDismissAlertMessage());
        },
        builder: (context, state) {
          if (state.cartLoading) return const CartShimmer();
          if (state.items.isEmpty) return const _EmptyCart();
          return _CartBody(
            state: state,
            onComingSoon: _showComingSoon,
            onRemoveItem: _removeItem,
            localityName: widget.localityName,
          );
        },
      ),
      bottomNavigationBar: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state.cartLoading || state.items.isEmpty) {
            return const SizedBox.shrink();
          }
          return _CartBottomBar(state: state, onComingSoon: _showComingSoon);
        },
      ),
    );
  }
}

class _CartBody extends StatelessWidget {
  const _CartBody({
    required this.state,
    required this.onComingSoon,
    required this.onRemoveItem,
    this.localityName,
  });

  final CartState state;
  final ValueChanged<String> onComingSoon;

  /// The area a newly added address is filed under.
  final String? localityName;

  /// Picks a different saved address for this booking, or adds one.
  Future<void> _changeAddress(BuildContext context) async {
    final bloc = context.read<CartBloc>();
    final chosen = await chooseAddress(
      context,
      localityName: localityName,
    );
    if (chosen == null) return;
    bloc.add(OnChangeAddress(chosen));
  }

  /// Removal is handled by the page, which owns the cart's bloc.
  final ValueChanged<CartItem> onRemoveItem;

  @override
  Widget build(BuildContext context) {
    final bookingDetails = state.bookingDetails;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingModeTabs(
            selected: state.mode,
            instantAvailable: state.instantAvailable,
            onChanged: (mode) =>
                context.read<CartBloc>().add(OnChangeBookingMode(mode)),
          ),
          const SizedBox(height: 20),
          CartSectionTitle(
            title: 'Review booking',
            trailing: Text(
              state.serviceCountLabel,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColor.neutralGreyColor600,
              ),
            ),
          ),
          ReviewBookingCard(
            items: state.items,
            showSlotCaveat: state.mode == CartBookingMode.schedule,
            onRemoveItem: onRemoveItem,
            // The catalogue is the screen that opened the cart, so adding
            // more services is a step back rather than a new push.
            onAddMoreServices: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 16),
          _CouponsRow(
            onTap: () => onComingSoon('Coupons are not available yet.'),
          ),
          const SizedBox(height: 24),
          const CartSectionTitle(title: 'Booking details'),
          if (bookingDetails != null)
            BookingDetailsCard(
              details: bookingDetails,
              scheduledForLabel: state.mode == CartBookingMode.schedule
                  ? state.scheduledForLabel
                  : null,
              onChangeSlot: () =>
                  showTimeSlotSheet(context, context.read<CartBloc>()),
              onEditAddress: () => _changeAddress(context),
              onEditContact: () =>
                  onComingSoon('Editing the contact is not available yet.'),
            ),
          const SizedBox(height: 24),
          const CartSectionTitle(title: 'Bill details'),
          BillDetailsCard(
            bill: state.bill,
            isExpanded: state.billExpanded,
            onToggle: () =>
                context.read<CartBloc>().add(const OnToggleBillDetails()),
          ),
        ],
      ),
    );
  }
}

class _CouponsRow extends StatelessWidget {
  const _CouponsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CartCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'View all coupons',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColor.neutralGreyColor700,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColor.neutralGreyColor400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The bar pinned to the bottom of the cart. What it offers depends on the
/// mode: book now, pick a time, pay for a booked time, or explain why the
/// selected mode cannot be completed and offer the one that can.
class _CartBottomBar extends StatelessWidget {
  const _CartBottomBar({required this.state, required this.onComingSoon});

  final CartState state;
  final ValueChanged<String> onComingSoon;

  @override
  Widget build(BuildContext context) {
    final cartBloc = context.read<CartBloc>();

    Widget? banner;
    late final String label;
    late final bool enabled;
    late final VoidCallback onPressed;

    if (state.isInstantBlocked) {
      banner = const ModeUnavailableBanner(
        title: 'Instant Currently unavailable',
        message:
            "Instant bookings can't be placed at this time. Please try "
            'again later.',
      );
      // The way out of a blocked instant booking is a scheduled one, so the
      // button moves the customer there rather than sitting disabled.
      label = 'Schedule now';
      enabled = true;
      onPressed = () =>
          cartBloc.add(const OnChangeBookingMode(CartBookingMode.schedule));
    } else if (state.mode == CartBookingMode.schedule && !state.hasSlot) {
      label = 'Select time slot';
      enabled = true;
      onPressed = () => showTimeSlotSheet(context, cartBloc);
    } else {
      label = 'Pay now | ${formatRupees(state.bill.toPay)}';
      enabled = state.canPay;
      // TODO: hand off to the payment flow once it exists.
      onPressed = () => onComingSoon('Payments are not available yet.');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?banner,
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: PrimaryButton(
              label: label,
              enabled: enabled,
              onPressed: onPressed,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: AppColor.neutralGreyColor200,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColor.neutralGreyColor700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Pick a service to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColor.neutralGreyColor500,
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Browse services',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColor.indicativeBlueColor500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
