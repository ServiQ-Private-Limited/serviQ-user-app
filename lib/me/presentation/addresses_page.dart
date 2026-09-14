import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:local_markerplace/basket/app_bottom_bar.dart';
import 'package:local_markerplace/components/motion/entrance.dart';
import 'package:local_markerplace/components/skeleton/skeleton.dart';
import 'package:local_markerplace/components/states/empty_state.dart';
import 'package:local_markerplace/components/states/error_state.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_assets.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_header.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_tab_bar.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/me/bloc/addresses_bloc.dart';
import 'package:local_markerplace/me/model/address_draft.dart';
import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/me/presentation/address_details_page.dart';
import 'package:local_markerplace/me/presentation/add_address_flow.dart';
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
    this.localityName,
    this.onTabSelected,
    this.onPost,
  });

  /// Defaults to the shared store, which is what the Me tab counts from.
  final AddressRepository? repository;

  /// The area the seeker has chosen, which a new address is filed under.
  final String? localityName;
  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          AddressesBloc(
            addressRepository: repository ?? AddressRepository.shared,
          )..add(const AddressesRequested()),
      child: _AddressesView(
        repository: repository,
        localityName: localityName,
        onTabSelected: onTabSelected,
        onPost: onPost,
      ),
    );
  }
}

class _AddressesView extends StatelessWidget {
  const _AddressesView({
    required this.repository,
    required this.localityName,
    required this.onTabSelected,
    required this.onPost,
  });

  final AddressRepository? repository;
  final String? localityName;
  final ValueChanged<DiscoveryTab>? onTabSelected;
  final VoidCallback? onPost;

  /// Adds an address and shows it, without the seeker having to pull to
  /// refresh a list they just added to.
  Future<void> _add(BuildContext context) async {
    final bloc = context.read<AddressesBloc>();
    final saved = await addAddressFlow(
      context,
      localityName: localityName,
      repository: repository,
    );
    if (saved == null) return;
    bloc.add(const AddressesRequested());
  }

  /// Removing an address, once the seeker has said they meant it.
  ///
  /// Asked first because it cannot be undone — there is no restore, and an
  /// address is typed out by hand.
  Future<void> _delete(BuildContext context, SavedAddress address) async {
    final id = address.id;
    if (id == null) return;
    final bloc = context.read<AddressesBloc>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColor.white,
        title: Text('Delete ${address.displayLabel}?', style: DiscoveryText.sheetTitle),
        content: Text(
          address.isDefault
              ? 'This is your default address. Another one will be used for '
                    'bookings instead.'
              : 'This cannot be undone.',
          style: DiscoveryText.publicNote,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('Keep it', style: DiscoveryText.inlineLinkMuted),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: DiscoveryText.inlineLink.copyWith(
                color: AppColor.authError,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    bloc.add(AddressDeleted(id));
  }

  /// Changes an address, on the same form that created it.
  ///
  /// The map step is skipped: the pin is already where the seeker put it, and
  /// an address the endpoint returned without coordinates has none to show.
  Future<void> _edit(BuildContext context, SavedAddress address) async {
    if (address.id == null) return;
    final bloc = context.read<AddressesBloc>();

    final updated = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(
        builder: (_) => AddressDetailsPage(
          editing: address,
          repository: repository,
          // Only when the server actually gave coordinates. Nothing is
          // invented to fill a null pin.
          draft: (address.lat == null || address.lng == null)
              ? null
              : AddressDraft(
                  latitude: address.lat!,
                  longitude: address.lng!,
                  placeName: address.localityName,
                  formattedAddress: address.landmark ?? '',
                  pincode: address.pincode,
                ),
        ),
      ),
    );

    if (updated != null) bloc.add(AddressUpdated(updated));
  }

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
      // A refused delete leaves the list perfectly readable, so it is said in
      // passing rather than taking the screen over with an error page.
      body: BlocListener<AddressesBloc, AddressesState>(
        listenWhen: (previous, current) =>
            previous.deleteFailure != current.deleteFailure &&
            current.deleteFailure != null,
        listener: (context, state) {
          _notice(
            context,
            "That didn't work. ${state.deleteFailure!.errorMessage}",
          );
          context.read<AddressesBloc>().add(const DeleteFailureDismissed());
        },
        child: SafeArea(
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
            onEdit: () => _edit(context, address),
            isDeleting: state.isDeleting(address.id),
            isPromoting: state.isPromoting(address.id),
            onDelete: () => _delete(context, address),
            onSetDefault: address.id == null
                ? null
                : () => context.read<AddressesBloc>().add(
                    AddressDefaultSet(address.id!),
                  ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        _AddAddressButton(onTap: () => _add(context)),
        const SizedBox(height: 12),
        // Both buttons open the same flow: it starts on the seeker's own
        // location anyway, so "Detect my location" is that flow without the
        // detour of dragging the map first.
        _DetectLocationButton(onTap: () => _add(context)),
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
      onPrimary: () => _add(context),
      secondaryLabel: 'Detect my location',
      onSecondary: () => _add(context),
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
    this.isDeleting = false,
    this.isPromoting = false,
  });

  final SavedAddress address;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onSetDefault;

  /// True while the server is being told. The card fades and stops taking
  /// taps rather than sitting there looking untouched.
  final bool isDeleting;

  /// True while this one is being made the default.
  final bool isPromoting;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDeleting ? 0.45 : 1,
      child: IgnorePointer(
        // Also while it is being promoted: the endpoint toggles, so a second
        // tap would clear the default it is in the middle of setting.
        ignoring: isDeleting || isPromoting,
        child: _card(context),
      ),
    );
  }

  Widget _card(BuildContext context) {
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
          const SizedBox(height: 4),
          Row(
            children: [
              // Pulled back so the padded target still lines up with the
              // address text above it.
              Transform.translate(
                offset: const Offset(-6, 0),
                child: _CardAction(label: 'Edit', onTap: onEdit),
              ),
              const SizedBox(width: 14),
              _CardAction(
                label: isDeleting ? 'Deleting…' : 'Delete',
                onTap: onDelete,
                // Destructive, so it is coloured as one rather than left
                // looking like a label nobody can press.
                tint: AppColor.authError,
                isBusy: isDeleting,
              ),
              const Spacer(),
              if (!address.isDefault)
                _CardAction(
                  label: isPromoting ? 'Setting…' : 'Set as default',
                  onTap: onSetDefault,
                  isBusy: isPromoting,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Edit / Delete / Set as default.
///
/// These were drawn in the muted grey the design uses for secondary text,
/// which is all but the same colour as the disabled one — so every action on
/// the card read as switched off. They carry their own colour now, sit in a
/// proper tap target rather than on the text's own bounds, and press.
class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.label,
    required this.onTap,
    this.tint,
    this.isBusy = false,
  });

  final String label;
  final VoidCallback? onTap;

  /// Defaults to the accent; red for the one that cannot be undone.
  final Color? tint;

  /// Greyed while the server is being told, which is the only time one of
  /// these genuinely is inert.
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final colour = isBusy
        ? AppColor.discoveryTextTertiary
        : (tint ?? AppColor.discoveryAccent);

    return PressableScale(
      onTap: isBusy ? null : onTap,
      pressedScale: 0.94,
      child: Padding(
        // A 12pt word is too small a thing to aim at on its own.
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: Text(
          label,
          style: DiscoveryText.inlineLink.copyWith(
            fontSize: 12.5,
            color: colour,
          ),
        ),
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
