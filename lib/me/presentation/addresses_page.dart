import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:local_markerplace/basket/app_bottom_bar.dart';
import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/components/states/empty_state.dart';
import 'package:local_markerplace/components/states/error_state.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_assets.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_header.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_tab_bar.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/me/bloc/addresses_bloc.dart';
import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/me/presentation/components/me_components.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';

/// 08 · Addresses.
///
/// The locality on an address is not just a delivery detail — it decides
/// which providers the seeker sees at all, which is why the screen says so
/// and shows the area under every address rather than only the street.
class AddressesPage extends StatelessWidget {
  const AddressesPage({
    super.key,
    this.repository,
    this.onTabSelected,
    this.onPost,
  });

  /// Defaults to the shared store, which is what the Me tab counts from.
  final AddressRepository? repository;
  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AddressesBloc(
            addressRepository: repository ?? AddressRepository.shared,
          )..add(const AddressesRequested()),
      child: _AddressesView(onTabSelected: onTabSelected, onPost: onPost),
    );
  }
}

class _AddressesView extends StatelessWidget {
  const _AddressesView({required this.onTabSelected, required this.onPost});

  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;

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
    final state = context.watch<AddressesBloc>().state;

    return Scaffold(
      backgroundColor: AppColor.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const DiscoveryHeader(title: 'Addresses'),
            const SizedBox(height: 14),
            const Divider(
              height: 1,
              thickness: 1,
              color: AppColor.discoveryBorder,
            ),
            Expanded(child: _body(context, state)),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomBar(
        current: DiscoveryTab.me,
        onSelect: (tab) => onTabSelected?.call(tab),
        onPost: onPost,
      ),
    );
  }

  Widget _body(BuildContext context, AddressesState state) {
    // Never a spinner: the screen wears the shape it is about to become.
    if (state.isLoading) {
      return const SkeletonList(caption: 'Loading your addresses', rows: 3);
    }
    if (state.failure != null) return _error(context, state);
    if (state.isEmpty) return _empty(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      children: [
        Text(
          'Used for visits and deliveries. The locality decides which '
          'providers you see.',
          style: DiscoveryText.publicNote,
        ),
        const SizedBox(height: 20),
        for (final address in state.addresses) ...[
          _AddressCard(
            // The server's id, so a rebuilt list keeps each card's own state
            // with the address rather than with the position it was in.
            key: address.id == null ? null : ValueKey(address.id),
            address: address,
            onEdit: () => _notice(context, 'Edit — coming soon.'),
            onDelete: () => _notice(context, 'Delete — coming soon.'),
            onSetDefault: () => _notice(
              context,
              '${address.displayLabel} is now your default address.',
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        _AddAddressButton(onTap: () => _notice(context, 'Add an address — coming soon.')),
        const SizedBox(height: 12),
        _DetectLocationButton(
          onTap: () => _notice(context, 'Location — coming soon.'),
        ),
      ],
    );
  }

  /// Loaded and there is nothing saved. Not a dead end: the two things worth
  /// doing about it are the same two the list offers.
  Widget _empty(BuildContext context) {
    return EmptyState(
      icon: Icons.location_on_outlined,
      title: 'No addresses saved yet',
      body:
          'Save where you need work done and it will be ready the next time '
          'you book, rather than typed out again.',
      primaryLabel: 'Add an address',
      primaryIcon: Icons.add_rounded,
      onPrimary: () => _notice(context, 'Add an address — coming soon.'),
      secondaryLabel: 'Detect my location',
      onSecondary: () => _notice(context, 'Location — coming soon.'),
    );
  }

  /// What went wrong, and the way out of it. Being offline and the server
  /// faulting read differently: one is the seeker's to act on, the other
  /// explicitly is not.
  Widget _error(BuildContext context, AddressesState state) {
    final isOffline = state.isOffline;

    return ErrorState(
      isOffline: isOffline,
      title: isOffline ? 'You are offline' : "Couldn't load your addresses",
      body: isOffline
          ? 'Nothing loaded because there is no connection. Your addresses '
                'will be here when you are back.'
          : 'Something went wrong on our side, not yours. Nothing you saved '
                'was lost.',
      onRetry: () =>
          context.read<AddressesBloc>().add(const AddressesRequested()),
      reference: isOffline ? null : state.failure?.errorCode,
      occurredAt: isOffline ? null : state.failedAt,
    );
  }
}

class _AddAddressButton extends StatelessWidget {
  const _AddAddressButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedActionButton(
      label: 'Add an address',
      leading: SvgPicture.asset(
        DiscoveryAssets.plus,
        width: 16,
        height: 16,
        colorFilter: const ColorFilter.mode(
          AppColor.discoveryGradientEnd,
          BlendMode.srcIn,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _DetectLocationButton extends StatelessWidget {
  const _DetectLocationButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedActionButton(
      label: 'Detect my location',
      height: 50,
      leading: SvgPicture.asset(
        DiscoveryAssets.addressPin,
        width: 13,
        height: 19,
      ),
      onTap: onTap,
    );
  }
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({
    super.key,
    required this.address,
    this.onEdit,
    this.onDelete,
    this.onSetDefault,
  });

  final SavedAddress address;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13.2),
      decoration: BoxDecoration(
        color: AppColor.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColor.discoveryBorder, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: AppColor.discoveryShadow.withValues(alpha: 0.05),
            blurRadius: 7,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SvgPicture.asset(
                  DiscoveryAssets.addressPin,
                  width: 14,
                  height: 20,
                ),
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
                          const SizedBox(width: 10),
                          const _DefaultPill(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(address.lines, style: DiscoveryText.addressLine),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            thickness: 1,
            color: AppColor.discoveryBorder,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              GestureDetector(
                onTap: onEdit,
                behavior: HitTestBehavior.opaque,
                child: Text('Edit', style: DiscoveryText.inlineLink),
              ),
              const SizedBox(width: 22),
              GestureDetector(
                onTap: onDelete,
                behavior: HitTestBehavior.opaque,
                child: Text('Delete', style: DiscoveryText.inlineLinkMuted),
              ),
              const Spacer(),
              if (!address.isDefault)
                GestureDetector(
                  onTap: onSetDefault,
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'Set as default',
                    style: DiscoveryText.inlineLinkMuted,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefaultPill extends StatelessWidget {
  const _DefaultPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 9, right: 10, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: AppColor.addressDefaultTint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'DEFAULT',
        style: DiscoveryText.pill.copyWith(
          color: AppColor.discoveryGradientEnd,
        ),
      ),
    );
  }
}
