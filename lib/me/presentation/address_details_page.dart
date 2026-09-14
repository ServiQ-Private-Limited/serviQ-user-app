import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:local_markerplace/components/app_back_button.dart';
import 'package:local_markerplace/components/primary_button.dart';
import 'package:local_markerplace/components/textfield.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/me/bloc/save_address_bloc.dart';
import 'package:local_markerplace/me/model/address_draft.dart';
import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';

/// Add address details — step two of two.
///
/// The pin is settled by now, so this screen only asks the two things a map
/// cannot know: which door, and what to call it. Pops with the [SavedAddress]
/// the server gave back.
class AddressDetailsPage extends StatelessWidget {
  const AddressDetailsPage({
    super.key,
    this.draft,
    this.editing,
    this.repository,
    this.localitySlug,
    this.makeDefault = false,
  });

  /// Where the pin was left. Null when editing an address the endpoint
  /// returned with no coordinates.
  final AddressDraft? draft;

  /// The address being changed, when this is an edit rather than a new one.
  final SavedAddress? editing;

  final AddressRepository? repository;

  /// The area the address is filed under — the one the seeker already chose.
  final String? localitySlug;

  /// True when this is their first address.
  final bool makeDefault;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SaveAddressBloc(
        addressRepository: repository ?? AddressRepository.shared,
        draft: draft,
        localitySlug: localitySlug,
        editing: editing,
      ),
      child: _AddressDetailsView(
        makeDefault: makeDefault,
        isEditing: editing != null,
      ),
    );
  }
}

class _AddressDetailsView extends StatefulWidget {
  const _AddressDetailsView({
    required this.makeDefault,
    required this.isEditing,
  });

  final bool makeDefault;
  final bool isEditing;

  @override
  State<_AddressDetailsView> createState() => _AddressDetailsViewState();
}

class _AddressDetailsViewState extends State<_AddressDetailsView> {
  final TextEditingController _house = TextEditingController();
  final TextEditingController _building = TextEditingController();
  final TextEditingController _label = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Editing starts from what is already saved, so the seeker changes a
    // field rather than typing the whole address again.
    final state = context.read<SaveAddressBloc>().state;
    _house.text = state.house;
    _building.text = state.building;
    _label.text = state.label;
  }

  @override
  void dispose() {
    _house.dispose();
    _building.dispose();
    _label.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.white,
      body: BlocConsumer<SaveAddressBloc, SaveAddressState>(
        listenWhen: (previous, current) =>
            previous.saved != current.saved && current.saved != null,
        listener: (context, state) => Navigator.of(context).pop(state.saved),
        builder: (context, state) {
          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(
                  title: widget.isEditing
                      ? 'Edit address'
                      : 'Add address details',
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom:
                          MediaQuery.viewInsetsOf(context).bottom + 24,
                    ),
                    children: [
                      // Only drawn when there is a pin to draw. An address
                      // the endpoint returned without coordinates gets no
                      // map rather than a map of somewhere it is not.
                      if (state.draft != null) ...[
                        _MapPreview(draft: state.draft!),
                        _ChosenPlace(
                          draft: state.draft!,
                          canChange: !widget.isEditing,
                        ),
                      ] else
                        const _NoPinNote(),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: AppColor.discoveryBorder,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add Address',
                              style: DiscoveryText.sectionTitleSmall,
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _house,
                              hintText: 'House No / Flat / Floor',
                              autofocus: !widget.isEditing,
                              textInputAction: TextInputAction.next,
                              onChanged: (value) => context
                                  .read<SaveAddressBloc>()
                                  .add(HouseChanged(value)),
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _building,
                              hintText: 'Building & Block No. (Optional)',
                              textInputAction: TextInputAction.next,
                              onChanged: (value) => context
                                  .read<SaveAddressBloc>()
                                  .add(BuildingChanged(value)),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              'Add Label',
                              style: DiscoveryText.sectionTitleSmall,
                            ),
                            const SizedBox(height: 12),
                            _LabelChips(
                              selected: state.label,
                              onChoose: (label) {
                                // The field and the chips are the same
                                // answer, so choosing one fills the other.
                                _label.text = label;
                                context
                                    .read<SaveAddressBloc>()
                                    .add(LabelSuggestionChosen(label));
                              },
                            ),
                            const SizedBox(height: 12),
                            AppTextField(
                              controller: _label,
                              hintText: 'Save address as (Home, Office ..)',
                              textInputAction: TextInputAction.done,
                              onChanged: (value) => context
                                  .read<SaveAddressBloc>()
                                  .add(LabelChanged(value)),
                            ),
                            if (state.failure != null) ...[
                              const SizedBox(height: 14),
                              Text(
                                state.failure!.errorMessage,
                                style: DiscoveryText.smallPrint.copyWith(
                                  color: AppColor.authError,
                                ),
                              ),
                            ],
                            const SizedBox(height: 26),
                            PrimaryButton(
                              label: widget.isEditing
                                  ? 'Save changes'
                                  : 'Save Address',
                              gradient: true,
                              enabled: state.canSave,
                              isLoading: state.isSaving,
                              onPressed: () =>
                                  context.read<SaveAddressBloc>().add(
                                    AddressSubmitted(
                                      makeDefault: widget.makeDefault,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The pin, shown rather than driven — this screen is about the door, and a
/// map you can move would invite changing the thing already settled. Change
/// goes back to step one, which is the screen for it.
class _MapPreview extends StatelessWidget {
  const _MapPreview({required this.draft});

  final AddressDraft draft;

  @override
  Widget build(BuildContext context) {
    final target = LatLng(draft.latitude, draft.longitude);

    return SizedBox(
      height: 170,
      child: IgnorePointer(
        child: Stack(
          alignment: Alignment.center,
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(target: target, zoom: 17),
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              liteModeEnabled: true,
              markers: {
                Marker(markerId: const MarkerId('chosen'), position: target),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Said plainly when the endpoint returned the address without coordinates.
///
/// Nothing is drawn in the map's place and nothing is guessed at: an address
/// saved through the API has no pin, and inventing one would put the provider
/// somewhere nobody lives.
class _NoPinNote extends StatelessWidget {
  const _NoPinNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Text(
        'This address has no map pin saved against it. You can change the '
        'details below; the location stays as it is.',
        style: DiscoveryText.publicNote,
      ),
    );
  }
}

class _ChosenPlace extends StatelessWidget {
  const _ChosenPlace({required this.draft, this.canChange = true});

  final AddressDraft draft;

  /// Editing has no step one behind it to go back to, so the link is left
  /// off rather than pointing nowhere.
  final bool canChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.placeName.isNotEmpty ? draft.placeName : 'Dropped pin',
                  style: DiscoveryText.sectionTitleSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  draft.formattedAddress.isNotEmpty
                      ? draft.formattedAddress
                      : 'The pin you dropped on the map.',
                  style: DiscoveryText.addressLine,
                ),
              ],
            ),
          ),
          if (canChange) ...[
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Back to step one, which is where a location is chosen —
              // rather than a second, smaller map here that does the same
              // job worse.
              onTap: () => Navigator.of(context).pop(),
              child: Text('Change', style: DiscoveryText.inlineLink),
            ),
          ],
        ],
      ),
    );
  }
}

/// Home / Office / PG / Chill Spot / Gym.
class _LabelChips extends StatelessWidget {
  const _LabelChips({required this.selected, required this.onChoose});

  final String selected;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final label in addressLabelSuggestions)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChoose(label),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: selected == label
                    ? AppColor.addressDefaultTint
                    : AppColor.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected == label
                      ? AppColor.discoveryGradientEnd
                      : AppColor.discoveryBorder,
                ),
              ),
              child: Text(
                label,
                style: DiscoveryText.rowTitle.copyWith(
                  fontSize: 13,
                  color: selected == label
                      ? AppColor.discoveryGradientEnd
                      : AppColor.discoveryInk,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 20, 10),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 8),
          Text(title, style: DiscoveryText.sheetTitle),
        ],
      ),
    );
  }
}
