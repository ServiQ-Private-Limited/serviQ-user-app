import 'package:local_markerplace/core/money.dart';
import 'package:local_markerplace/provider/model/provider_detail.dart';
import 'package:local_markerplace/provider/model/provider_service.dart';
import 'package:local_markerplace/provider/model/store_product.dart';

/// Turning what the endpoints send into what the rows draw.
///
/// Only formatting happens here — paise into rupees, a stock count into the
/// line above it, a list of days into a block of hours. Nothing is added
/// that the server did not send: a field it returns as null comes out empty,
/// and the row leaves it off rather than filling it in.
extension ProviderServiceDisplay on ProviderServiceItem {
  /// "from ₹599", from `fromPricePaise`.
  String get fromPriceLabel => 'from ${rupees(fromPricePaise / 100)}';

  /// The line under the name. The endpoint sends `description` as null on
  /// every service, so the unit — "per unit", "per visit" — is what there is
  /// to say; where there is neither, the row shows nothing.
  String get detailLabel => description?.trim().isNotEmpty == true
      ? description!.trim()
      : (unit?.trim() ?? '');

  ProviderService get asDisplay => ProviderService(
    name: name,
    fromPrice: fromPriceLabel,
    detail: detailLabel,
  );
}

extension ProviderProductDisplay on ProviderProductItem {
  /// "₹349", from `pricePaise`.
  String get priceLabel => rupees(pricePaise / 100);

  /// The real count rather than a judgement about it: the endpoint says how
  /// many there are, so that is what the card says.
  String get stockLabel =>
      stockCount <= 0 ? 'Out of stock' : '$stockCount in stock';

  StoreProduct get asDisplay => StoreProduct(
    name: name,
    price: priceLabel,
    stockLabel: stockLabel,
    // Null on every product the endpoint returns; an empty detail is what
    // the product screen reads as "nothing written about this yet".
    detail: description?.trim() ?? '',
    // The endpoint does not say which of the provider's services fits a
    // part, so nothing is offered. It is not that there is no such service
    // — it is that nothing here knows.
    isLow: stockCount <= 0,
  );
}

extension ProviderAvailabilityDisplay on List<ProviderAvailabilityDay> {
  /// The week as a block of lines, in the order the endpoint numbers them.
  ///
  /// Written a day per line rather than collapsed into "Mon–Sat": collapsing
  /// assumes the middle of a run matches its ends, and a provider closed on
  /// a Wednesday would be advertised as open.
  String get hoursBlock {
    final days = [...this]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
    return days
        .map((day) => '${day.dayName} · ${day.hoursLabel}')
        .join('\n');
  }
}

extension ProviderDetailDisplay on ProviderDetail {
  /// The areas they work in, one per line, as the endpoint lists them.
  String get coverageBlock =>
      coverage.map((locality) => locality.name).join('\n');

  /// "Galleria Market 1 · Crossing Republik" — where the shop itself is.
  String get homeLocalityLine {
    final home = homeLocality;
    if (home == null) return '';
    if (home.zoneName.isEmpty) return home.name;
    return '${home.name} · ${home.zoneName}';
  }

  /// The address as the endpoint sends it, with the area under it. Both are
  /// left out when the server sends neither.
  String get addressBlock {
    final parts = [
      if (addressLine?.trim().isNotEmpty == true) addressLine!.trim(),
      if (homeLocalityLine.isNotEmpty) homeLocalityLine,
    ];
    return parts.join('\n');
  }

  /// "Usually replies in 1 min". Empty when the server sends no time, and
  /// then the hero leaves the line out.
  String get responseLine {
    final minutes = responseTimeMinutes;
    if (minutes == null) return '';
    return 'usually replies in $minutes ${minutes == 1 ? 'min' : 'mins'}';
  }

  /// "Open now" / "Closed", paired with the trades when there are any.
  String get heroLine {
    final parts = [
      if (tradeLine.isNotEmpty) tradeLine,
      openNow ? 'Open now' : 'Closed',
      if (responseLine.isNotEmpty) responseLine,
    ];
    return parts.join(' · ');
  }
}
