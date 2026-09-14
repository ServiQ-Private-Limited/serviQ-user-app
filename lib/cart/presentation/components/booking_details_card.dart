import 'package:flutter/material.dart';
import 'package:local_markerplace/cart/model/booking_details.dart';
import 'package:local_markerplace/cart/presentation/components/cart_card.dart';
import 'package:local_markerplace/core/app_color.dart';

/// Where the visit happens and who it is for — plus, once a slot is
/// confirmed, when.
class BookingDetailsCard extends StatelessWidget {
  const BookingDetailsCard({
    super.key,
    required this.details,
    required this.scheduledForLabel,
    required this.onChangeSlot,
    required this.onEditAddress,
    required this.onEditContact,
  });

  final BookingDetails details;

  /// Summary of the confirmed slot, or null while none is chosen — in which
  /// case the card has no timing row at all.
  final String? scheduledForLabel;

  final VoidCallback onChangeSlot;
  final VoidCallback onEditAddress;
  final VoidCallback onEditContact;

  @override
  Widget build(BuildContext context) {
    final label = scheduledForLabel;

    return CartCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          if (label != null) ...[
            _ScheduledRow(label: label, onChangeSlot: onChangeSlot),
            const _RowDivider(),
          ],
          _DetailRow(
            icon: Icons.location_on_outlined,
            title: details.addressTitle,
            subtitle: details.addressLine,
            onTap: onEditAddress,
          ),
          const _RowDivider(),
          _DetailRow(
            icon: Icons.phone_in_talk_outlined,
            title: details.customerName,
            subtitle: details.customerPhone,
            onTap: onEditContact,
          ),
        ],
      ),
    );
  }
}

class _ScheduledRow extends StatelessWidget {
  const _ScheduledRow({required this.label, required this.onChangeSlot});

  final String label;
  final VoidCallback onChangeSlot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 22,
            color: AppColor.neutralGreyColor500,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scheduled for',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColor.neutralGreyColor500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColor.neutralGreyColor800,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: onChangeSlot,
                  borderRadius: BorderRadius.circular(6),
                  child: const Text(
                    'Change slot',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColor.indicativeBlueColor500,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColor.indicativeBlueColor500,
                    ),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColor.neutralGreyColor500),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColor.neutralGreyColor800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColor.neutralGreyColor500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColor.neutralGreyColor400,
            ),
          ],
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColor.neutralGreyColor70,
    );
  }
}
