import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_markerplace/visit/bloc/orders_bloc.dart';

import 'package:local_markerplace/basket/app_bottom_bar.dart';
import 'package:local_markerplace/components/art/seeded_artwork.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/core/money.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_header.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_tab_bar.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/visit/model/visit.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/presentation/components/cart_bits.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

/// Everything the seeker has booked, newest first.
///
/// One entry per booking rather than per provider: two visits from the same
/// person on different days are two orders, and the reference is what either
/// of them is quoted by.
class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({
    super.key,
    this.repository,
    this.onTabSelected,
    this.onPost,
    this.onBrowse,
  });

  final VisitRepository? repository;
  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;

  /// Sends the seeker to find a provider from the empty state.
  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          OrdersBloc(visitRepository: repository ?? VisitRepository.shared)
            ..add(const OrdersRequested()),
      child: _MyOrdersView(
        onTabSelected: onTabSelected,
        onPost: onPost,
        onBrowse: onBrowse,
      ),
    );
  }
}

class _MyOrdersView extends StatelessWidget {
  const _MyOrdersView({
    required this.onTabSelected,
    required this.onPost,
    required this.onBrowse,
  });

  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;
  final VoidCallback? onBrowse;

  void _notice(BuildContext context, String message) {
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
    final orders = context.watch<OrdersBloc>().state.orders;

    return Scaffold(
      backgroundColor: AppColor.discoveryTint,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            DiscoveryHeader(
              title: 'My orders',
              subtitle: orders.isEmpty
                  ? null
                  : '${orders.length} '
                        '${orders.length == 1 ? 'booking' : 'bookings'}',
            ),
            const SizedBox(height: 14),
            Expanded(
              child: orders.isEmpty
                  ? _NoOrders(onBrowse: onBrowse)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: orders.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => FadeSlideIn(
                        index: index,
                        child: OrderCard(
                          order: orders[index],
                          onTrack: () => _notice(
                            context,
                            'Tracking a visit — coming soon.',
                          ),
                          onChat: () => _notice(context, 'Chat — coming soon.'),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: onTabSelected == null
          ? null
          : AppBottomBar(
              current: DiscoveryTab.me,
              // The shell returns to itself; popping here too would take it
              // off the stack and leave the app black.
              onSelect: (tab) => onTabSelected!(tab),
              onPost: onPost,
            ),
    );
  }
}

/// One booking: who is coming, when, what for, and what it comes to.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    required this.onTrack,
    required this.onChat,
  });

  final Visit order;
  final VoidCallback onTrack;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    return CartCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ORDER ${order.reference ?? ''}'.trim(),
                  style: DiscoveryText.tipsHeading,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColor.discoveryLiveTint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'BOOKED',
                  style: DiscoveryText.stockIn.copyWith(letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: SeededArtwork(
                  seed: order.providerName,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.providerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DiscoveryText.rowTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.whenLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: DiscoveryText.smallPrint,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(rupees(order.estimate), style: DiscoveryText.chip),
            ],
          ),
          const CartDivider(top: 12, bottom: 12),
          for (final service in order.services)
            _Line(
              name: service.name,
              detail: service.quantityLabel,
              value: rupees(service.lineTotal),
            ),
          for (final part in order.parts)
            _Line(
              name: part.name,
              detail: part.quantityLabel,
              value: rupees(part.lineTotal),
            ),
          const SizedBox(height: 4),
          Text(
            order.addressSummary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DiscoveryText.fine,
          ),
          const SizedBox(height: 4),
          Text(
            'Pay by ${order.payment.receiptLabel}',
            style: DiscoveryText.fine,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Action(label: 'Track visit', onTap: onTrack),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Action(label: 'Chat', onTap: onChat),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.name, required this.detail, required this.value});

  final String name;
  final String detail;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DiscoveryText.caption,
          ),
        ),
        const SizedBox(width: 8),
        Text(detail, style: DiscoveryText.meta),
        const SizedBox(width: 10),
        Text(value, style: DiscoveryText.chip),
      ],
    ),
  );
}

class _Action extends StatelessWidget {
  const _Action({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.96,
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColor.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColor.discoveryAccent.withValues(alpha: 0.35),
            width: 1.4,
          ),
        ),
        child: Text(
          label,
          style: DiscoveryText.actionOutlined.copyWith(fontSize: 13.5),
        ),
      ),
    );
  }
}

class _NoOrders extends StatelessWidget {
  const _NoOrders({required this.onBrowse});

  final VoidCallback? onBrowse;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 128,
              height: 128,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColor.white,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 50,
                color: AppColor.discoveryTextTertiary,
              ),
            ),
          ),
          const SizedBox(height: 26),
          Text(
            'No orders yet',
            textAlign: TextAlign.center,
            style: DiscoveryText.emptyTitle,
          ),
          const SizedBox(height: 10),
          Text(
            'Anything you book shows up here — who is coming, when, and what '
            'it costs.',
            textAlign: TextAlign.center,
            style: DiscoveryText.caption.copyWith(height: 19 / 12.5),
          ),
          if (onBrowse != null) ...[
            const SizedBox(height: 24),
            PressableScale(
              onTap: onBrowse,
              pressedScale: 0.97,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [
                      AppColor.discoveryGradientStart,
                      AppColor.discoveryGradientEnd,
                    ],
                  ),
                ),
                child: Text(
                  'Find a provider',
                  style: DiscoveryText.onAccent(16, letterSpacing: -0.16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
