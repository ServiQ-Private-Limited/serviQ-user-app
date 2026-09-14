import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/components/states/error_state.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/me/bloc/addresses_bloc.dart';
import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/me/presentation/add_address_flow.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';

/// Which address a booking is going to.
///
/// Opened from the cart and from a visit, where the seeker is part-way
/// through something — so it is a sheet over what they were doing rather
/// than a screen that takes them away from it. Returns the chosen address,
/// or null if they closed it without changing anything.
Future<SavedAddress?> chooseAddress(
  BuildContext context, {
  required String? localityName,
  AddressRepository? repository,
  int? currentId,
}) {
  return showModalBottomSheet<SavedAddress>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColor.white,
    barrierColor: AppColor.discoveryInk.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => ChooseAddressSheet(
      localityName: localityName,
      repository: repository,
      currentId: currentId,
    ),
  );
}

class ChooseAddressSheet extends StatelessWidget {
  const ChooseAddressSheet({
    super.key,
    this.localityName,
    this.repository,
    this.currentId,
  });

  final String? localityName;
  final AddressRepository? repository;

  /// The address already on the booking, marked so the seeker can see what
  /// they are changing from.
  final int? currentId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AddressesBloc(
            addressRepository: repository ?? AddressRepository.shared,
          )..add(const AddressesRequested()),
      child: _ChooseAddressView(
        localityName: localityName,
        repository: repository,
        currentId: currentId,
      ),
    );
  }
}

class _ChooseAddressView extends StatelessWidget {
  const _ChooseAddressView({
    required this.localityName,
    required this.repository,
    required this.currentId,
  });

  final String? localityName;
  final AddressRepository? repository;
  final int? currentId;

  Future<void> _add(BuildContext context) async {
    final navigator = Navigator.of(context);
    final saved = await addAddressFlow(
      context,
      localityName: localityName,
      repository: repository,
    );
    // A newly saved address is the one they wanted — handing it straight back
    // saves them picking it out of the list they just added it to.
    if (saved != null) navigator.pop(saved);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AddressesBloc>().state;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppColor.discoveryBorder,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 17),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Where should they come?',
                    style: DiscoveryText.sheetTitle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: state.isLoading
                ? const SkeletonList(caption: 'Loading your addresses', rows: 3)
                : state.failure != null
                ? ErrorState(
                    isOffline: state.isOffline,
                    title: state.isOffline
                        ? 'You are offline'
                        : "Couldn't load your addresses",
                    body: state.isOffline
                        ? 'Your addresses will be here when you are back.'
                        : 'Something went wrong on our side, not yours.',
                    onRetry: () => context.read<AddressesBloc>().add(
                      const AddressesRequested(),
                    ),
                    reference: state.isOffline
                        ? null
                        : state.failure?.errorCode,
                    occurredAt: state.isOffline ? null : state.failedAt,
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      for (final address in state.addresses) ...[
                        _AddressOption(
                          address: address,
                          isCurrent: address.id != null &&
                              address.id == currentId,
                          onTap: () => Navigator.of(context).pop(address),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (state.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            'You have not saved an address yet. Add one and '
                            'the provider will know where to come.',
                            textAlign: TextAlign.center,
                            style: DiscoveryText.publicNote,
                          ),
                        ),
                      const SizedBox(height: 6),
                      _AddAnother(onTap: () => _add(context)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AddressOption extends StatelessWidget {
  const _AddressOption({
    required this.address,
    required this.isCurrent,
    required this.onTap,
  });

  final SavedAddress address;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCurrent ? AppColor.addressDefaultTint : AppColor.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent
                ? AppColor.discoveryGradientEnd
                : AppColor.discoveryBorder,
            width: 1.4,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isCurrent
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: isCurrent
                  ? AppColor.discoveryGradientEnd
                  : AppColor.discoveryTextTertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          address.displayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: DiscoveryText.sectionTitleSmall,
                        ),
                      ),
                      if (address.isDefault) ...[
                        const SizedBox(width: 8),
                        Text('· Default', style: DiscoveryText.metaMuted),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(address.lines, style: DiscoveryText.addressLine),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddAnother extends StatelessWidget {
  const _AddAnother({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColor.discoveryGradientEnd, width: 1.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_rounded,
              size: 18,
              color: AppColor.discoveryGradientEnd,
            ),
            const SizedBox(width: 8),
            Text(
              'Add a new address',
              style: DiscoveryText.inlineLink.copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
