import 'package:flutter/material.dart';

import 'package:local_markerplace/discovery/repository/home_repository.dart';
import 'package:local_markerplace/me/model/address_draft.dart';
import 'package:local_markerplace/me/model/saved_address.dart';
import 'package:local_markerplace/me/presentation/address_details_page.dart';
import 'package:local_markerplace/me/presentation/pick_location_page.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';
import 'package:local_markerplace/me/repository/place_lookup.dart';

/// Adding an address: the map, then the door.
///
/// The two screens are separate because the questions are — and because
/// "Change" on the second has somewhere to go back to. Returns the saved
/// address, or null if the seeker backed out of either step.
///
/// The loop matters: backing out of the details screen returns to the map
/// rather than abandoning the whole thing, which is what "Change" means.
Future<SavedAddress?> addAddressFlow(
  BuildContext context, {
  required String? localityName,
  AddressRepository? repository,
  PlaceLookup? placeLookup,
  AddressDraft? startAt,
  bool makeDefault = false,
}) async {
  final addresses = repository ?? AddressRepository.shared;
  // The area the seeker has already chosen, not one read off the map: the
  // endpoint refuses a slug it does not know, and this is the area that
  // decides which providers they see.
  final slug = localityName == null || localityName.trim().isEmpty
      ? null
      : HomeRepository.slugFor(localityName);

  var from = startAt;
  while (true) {
    if (!context.mounted) return null;
    final draft = await Navigator.of(context).push<AddressDraft>(
      MaterialPageRoute(
        builder: (_) =>
            PickLocationPage(placeLookup: placeLookup, startAt: from),
      ),
    );
    if (draft == null) return null;

    if (!context.mounted) return null;
    final saved = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(
        builder: (_) => AddressDetailsPage(
          draft: draft,
          repository: addresses,
          localitySlug: slug,
          // The first address a seeker saves is the one every booking will
          // use, so it is made the default rather than waiting to be picked.
          makeDefault: makeDefault || (addresses.count ?? 0) == 0,
        ),
      ),
    );
    if (saved != null) return saved;

    // Backed out of the details screen — "Change" — so the map opens again
    // where they left it rather than hunting for them a second time.
    from = draft;
  }
}
