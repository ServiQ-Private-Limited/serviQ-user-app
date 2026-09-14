import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:local_markerplace/visit/bloc/visit_bloc.dart';

import 'package:local_markerplace/components/motion/app_motion.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_header.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/visit/model/visit.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/model/visit_mode.dart';
import 'package:local_markerplace/visit/presentation/components/visit_bits.dart';
import 'package:local_markerplace/visit/presentation/visit_booked_page.dart';
import 'package:local_markerplace/me/presentation/choose_address_sheet.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

/// 13 · 05 — the last look before a visit is booked.
///
/// Everything here is already decided; the screen exists so nothing is a
/// surprise — who is coming, when, where, what it costs and how it gets
/// paid, with a way back to each.
class ConfirmVisitPage extends StatelessWidget {
  const ConfirmVisitPage({
    super.key,
    required this.providerName,
    this.repository,
    this.localityName,
  });

  /// Whose cart is being confirmed.
  final String providerName;

  final VisitRepository? repository;

  /// The area a newly added address is filed under.
  final String? localityName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          VisitBloc(visitRepository: repository ?? VisitRepository.shared)
            ..add(CartOpened(providerName)),
      child: _ConfirmVisitView(localityName: localityName),
    );
  }
}

class _ConfirmVisitView extends StatelessWidget {
  const _ConfirmVisitView({this.localityName});

  final String? localityName;

  /// Changing where the provider is being sent, from the last screen before
  /// it is booked — which is the last moment it can be put right.
  Future<void> _changeAddress(BuildContext context, Visit visit) async {
    final bloc = context.read<VisitBloc>();
    final chosen = await chooseAddress(
      context,
      localityName: localityName,
      currentId: visit.addressId,
    );
    if (chosen == null) return;
    bloc.add(CartAddressChosen(chosen));
  }

  /// Everything behind this screen is about a visit that no longer exists to
  /// edit — going back to the slot picker would land on "nothing on this
  /// visit yet". So the booked screen replaces the whole flow and sits on
  /// the shell, where back means home.
  Future<void> _showReceipt(BuildContext context, Visit booked) {
    return Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => VisitBookedPage(visit: booked)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<VisitBloc>().state;
    final visit = state.cart;
    if (visit == null) return const SizedBox.shrink();

    return BlocListener<VisitBloc, VisitState>(
      listenWhen: (previous, current) =>
          previous.booked != current.booked && current.booked != null,
      listener: (context, state) => _showReceipt(context, state.booked!),
      child: Scaffold(
        backgroundColor: AppColor.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const DiscoveryHeader(title: 'Confirm visit'),
              const SizedBox(height: 14),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColor.discoveryBorder,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProviderStrip(visit: visit),
                      const SizedBox(height: 14),
                      _DetailCard(
                        icon: visit.mode == VisitMode.instant
                            ? Icons.bolt_rounded
                            : Icons.event_available_rounded,
                        title: visit.whenLabel,
                        subtitle: '${visit.mode?.label ?? ''} visit',
                        // Going back is how the slot or the mode is changed —
                        // this screen only reports them.
                        onChange: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(height: 12),
                      _DetailCard(
                        icon: Icons.place_outlined,
                        title: visit.addressTitle,
                        subtitle: visit.addressSubtitle,
                        onChange: () => _changeAddress(context, visit),
                      ),
                      const SizedBox(height: 22),
                      Text('SERVICES', style: DiscoveryText.tipsHeading),
                      const SizedBox(height: 12),
                      for (final service in visit.services)
                        TotalRow(
                          label: '${service.name} × ${service.quantity}',
                          value: rupees(service.lineTotal),
                        ),
                      if (visit.parts.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('PARTS', style: DiscoveryText.tipsHeading),
                        const SizedBox(height: 12),
                        for (final part in visit.parts)
                          TotalRow(
                            label: '${part.name} × ${part.quantity}',
                            value: rupees(part.lineTotal),
                          ),
                      ],
                      if (visit.instantFee > 0)
                        TotalRow(
                          label: 'Instant fee',
                          value: rupees(visit.instantFee),
                        ),
                      const VisitRule(top: 6, bottom: 14),
                      const TotalRow(label: 'Visit charge', value: 'waived'),
                      TotalRow(
                        label: 'Estimate',
                        value: rupees(visit.estimate),
                        isTotal: true,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        visit.parts.isEmpty
                            ? 'You pay after the work is done. The provider '
                                  'confirms the final price before starting.'
                            : 'The provider brings the parts on the visit. You '
                                  'pay once the work is done.',
                        style: DiscoveryText.smallPrint,
                      ),
                      const SizedBox(height: 24),
                      Text('PAYMENT', style: DiscoveryText.tipsHeading),
                      const SizedBox(height: 12),
                      for (final method in VisitPayment.values) ...[
                        _PaymentRow(
                          method: method,
                          isSelected: visit.payment == method,
                          onTap: () => context.read<VisitBloc>().add(
                            CartPaymentChosen(method),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: AppColor.white,
              border: Border(top: BorderSide(color: AppColor.discoveryBorder)),
            ),
            child: VisitCta(
              label: 'Confirm visit',
              onTap: () => context.read<VisitBloc>().add(const CartConfirmed()),
            ),
          ),
        ),
      ),
    );
  }

}

/// When, or where — a fact with a way to change it.
class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChange,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColor.providerNoteFill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColor.discoveryAccent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DiscoveryText.rowTitle.copyWith(fontSize: 13.5),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DiscoveryText.smallPrint,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PressableScale(
            onTap: onChange,
            pressedScale: 0.9,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Text(
                'Change',
                style: DiscoveryText.reviewAge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColor.discoveryAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  final VisitPayment method;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.98,
      child: AnimatedContainer(
        duration: AppMotion.quick,
        curve: AppMotion.emphasized,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColor.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColor.discoveryAccent
                : AppColor.discoveryBorder,
            width: isSelected ? 2 : 1.4,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColor.discoveryAccent
                      : AppColor.uploadDashedBorder,
                  width: 2,
                ),
              ),
              child: AnimatedScale(
                scale: isSelected ? 1 : 0,
                duration: AppMotion.quick,
                curve: AppMotion.overshoot,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColor.discoveryAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.label,
                    style: DiscoveryText.rowTitle.copyWith(fontSize: 13.5),
                  ),
                  const SizedBox(height: 3),
                  Text(method.detail, style: DiscoveryText.smallPrint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
