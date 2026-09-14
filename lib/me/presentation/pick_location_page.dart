import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:local_markerplace/components/app_back_button.dart';
import 'package:local_markerplace/components/primary_button.dart';
import 'package:local_markerplace/components/textfield.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/me/bloc/pick_location_bloc.dart';
import 'package:local_markerplace/me/model/address_draft.dart';
import 'package:local_markerplace/me/repository/place_lookup.dart';

/// Add delivery location — step one of two.
///
/// The map is the input: the seeker drags until the pin is over their door
/// and the address underneath keeps up. Confirm hands the pin to step two
/// rather than saving anything, because where a place is and what it is
/// called are two different questions.
class PickLocationPage extends StatelessWidget {
  const PickLocationPage({super.key, this.placeLookup, this.startAt});

  final PlaceLookup? placeLookup;

  /// Where to open, when an address is being moved rather than added.
  final AddressDraft? startAt;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PickLocationBloc(placeLookup: placeLookup ?? DevicePlaceLookup.shared)
            ..add(PickLocationStarted(startAt: startAt)),
      child: const _PickLocationView(),
    );
  }
}

class _PickLocationView extends StatefulWidget {
  const _PickLocationView();

  @override
  State<_PickLocationView> createState() => _PickLocationViewState();
}

class _PickLocationViewState extends State<_PickLocationView> {
  final TextEditingController _search = TextEditingController();
  GoogleMapController? _map;

  @override
  void dispose() {
    _search.dispose();
    _map?.dispose();
    super.dispose();
  }

  /// Only for the states that asked the map to move — a fix or a chosen
  /// search result. Moving it after a drag would fight the seeker's thumb.
  void _recentre(AddressDraft draft) {
    _map?.animateCamera(
      CameraUpdate.newLatLng(LatLng(draft.latitude, draft.longitude)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColor.white,
      body: BlocConsumer<PickLocationBloc, PickLocationState>(
        listenWhen: (previous, current) =>
            current.recentre && current.draft != null,
        listener: (context, state) => _recentre(state.draft!),
        builder: (context, state) {
          final draft = state.draft ?? DevicePlaceLookup.fallback;

          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _Header(title: 'Add delivery location'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                  child: AppTextField(
                    controller: _search,
                    hintText: 'Search delivery location',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: AppColor.discoveryTextTertiary,
                    ),
                    textInputAction: TextInputAction.search,
                    onChanged: (value) => context
                        .read<PickLocationBloc>()
                        .add(LocationSearched(value)),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      _Map(
                        draft: draft,
                        onCreated: (controller) {
                          _map = controller;
                          _recentre(draft);
                        },
                        onMoved: (position) => context
                            .read<PickLocationBloc>()
                            .add(
                              PinMoved(
                                latitude: position.latitude,
                                longitude: position.longitude,
                              ),
                            ),
                      ),
                      // The results cover the map while they are up: the
                      // seeker is choosing from a list, not looking at it.
                      if (state.results.isNotEmpty || state.isSearching)
                        _Results(
                          state: state,
                          onChoose: (chosen) {
                            _search.clear();
                            FocusScope.of(context).unfocus();
                            context
                                .read<PickLocationBloc>()
                                .add(SearchResultChosen(chosen));
                          },
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 16,
                        child: Center(
                          child: _LocateMeButton(
                            isLocating: state.isLocating,
                            onTap: () => context
                                .read<PickLocationBloc>()
                                .add(const LocateMePressed()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _Confirmation(state: state),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The map, with the pin fixed to the middle of it.
///
/// The design drags the map under a stationary pin rather than dragging the
/// pin around the map — it keeps the thing being placed at the centre of
/// attention and under the thumb rather than beneath it.
class _Map extends StatelessWidget {
  const _Map({
    required this.draft,
    required this.onCreated,
    required this.onMoved,
  });

  final AddressDraft draft;
  final ValueChanged<GoogleMapController> onCreated;
  final ValueChanged<LatLng> onMoved;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(draft.latitude, draft.longitude),
            zoom: 17,
          ),
          onMapCreated: onCreated,
          onCameraIdle: () {},
          onCameraMove: (position) => onMoved(position.target),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
        ),
        // Sits a little above centre so the point of the pin, not its body,
        // is over the spot the camera is reporting.
        const Padding(
          padding: EdgeInsets.only(bottom: 34),
          child: Icon(
            Icons.location_on,
            size: 44,
            color: AppColor.authError,
          ),
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.state, required this.onChoose});

  final PickLocationState state;
  final ValueChanged<AddressDraft> onChoose;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: AppColor.white,
        child: state.isSearching
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text('Looking…'),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.results.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 56,
                  color: AppColor.discoveryBorder,
                ),
                itemBuilder: (context, index) {
                  final result = state.results[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.place_outlined,
                      color: AppColor.discoveryTextTertiary,
                    ),
                    title: Text(
                      result.placeName,
                      style: DiscoveryText.rowTitle,
                    ),
                    subtitle: Text(
                      result.formattedAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: DiscoveryText.smallPrint,
                    ),
                    onTap: () => onChoose(result),
                  );
                },
              ),
      ),
    );
  }
}

class _LocateMeButton extends StatelessWidget {
  const _LocateMeButton({required this.isLocating, required this.onTap});

  final bool isLocating;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColor.white,
      borderRadius: BorderRadius.circular(10),
      elevation: 2,
      child: InkWell(
        onTap: isLocating ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColor.discoveryGradientEnd),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: isLocating
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : const Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: AppColor.discoveryGradientEnd,
                      ),
              ),
              const SizedBox(width: 10),
              Text(
                isLocating ? 'LOCATING…' : 'LOCATE ME',
                style: DiscoveryText.pill.copyWith(
                  color: AppColor.discoveryGradientEnd,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What is under the pin, and the way on.
class _Confirmation extends StatelessWidget {
  const _Confirmation({required this.state});

  final PickLocationState state;

  @override
  Widget build(BuildContext context) {
    final draft = state.draft;
    final failure = state.failure;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColor.white,
        border: Border(top: BorderSide(color: AppColor.discoveryBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (failure != null) ...[
            Text(
              failure.errorMessage,
              style: DiscoveryText.smallPrint.copyWith(
                color: AppColor.authError,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(
                  Icons.near_me,
                  size: 18,
                  color: AppColor.discoveryGradientEnd,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.isResolving
                          ? 'Finding that address…'
                          : (draft?.placeName.isNotEmpty == true
                                ? draft!.placeName
                                : 'Move the map to your address'),
                      style: DiscoveryText.sectionTitleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft?.formattedAddress.isNotEmpty == true
                          ? draft!.formattedAddress
                          : 'Drag the map until the pin is over your door.',
                      style: DiscoveryText.addressLine,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Confirm',
            gradient: true,
            enabled: state.canConfirm,
            onPressed: () => Navigator.of(context).pop(state.draft),
          ),
        ],
      ),
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
