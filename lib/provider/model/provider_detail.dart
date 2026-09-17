import 'package:equatable/equatable.dart';

/// A locality as `/api/v1/user/providers/{slug}` describes one — the shop's
/// own, and each area it covers.
class ProviderLocality extends Equatable {
  const ProviderLocality({
    required this.slug,
    required this.name,
    required this.localityType,
    required this.zoneSlug,
    required this.zoneName,
    this.lat,
    this.lng,
    this.radiusKm,
    this.providerCount,
  });

  final String slug;
  final String name;

  /// "MARKET" / "SOCIETY", as the server spells it.
  final String localityType;

  final String zoneSlug;
  final String zoneName;

  final double? lat;
  final double? lng;
  final double? radiusKm;
  final int? providerCount;

  factory ProviderLocality.fromJson(Map<String, dynamic> json) {
    return ProviderLocality(
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      localityType: json['localityType'] as String? ?? '',
      zoneSlug: json['zoneSlug'] as String? ?? '',
      zoneName: json['zoneName'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      radiusKm: (json['radiusKm'] as num?)?.toDouble(),
      providerCount: (json['providerCount'] as num?)?.toInt(),
    );
  }

  @override
  List<Object?> get props => [slug, name, localityType, zoneSlug, zoneName];
}

/// A trade the provider works in.
class ProviderCategory extends Equatable {
  const ProviderCategory({
    required this.id,
    required this.slug,
    required this.tradeName,
    required this.needName,
    this.icon,
  });

  final int id;
  final String slug;

  /// "Electrician" — what they are called.
  final String tradeName;

  /// "Electrical & plumbing" — the need a seeker would search under.
  final String needName;

  /// The server's icon key, e.g. "bolt". Null when it sends none.
  final String? icon;

  factory ProviderCategory.fromJson(Map<String, dynamic> json) {
    return ProviderCategory(
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: json['slug'] as String? ?? '',
      tradeName: json['tradeName'] as String? ?? '',
      needName: json['needName'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, slug, tradeName, needName, icon];
}

/// What the provider is rated, and how those stars are spread.
class ProviderRating extends Equatable {
  const ProviderRating({
    required this.average,
    required this.total,
    required this.breakdown,
  });

  final double average;

  /// How many reviews the average is drawn from. Zero means unrated, which
  /// the screen says rather than drawing an empty five stars.
  final int total;

  /// Count per star, keyed 1 to 5 as the endpoint sends them.
  final Map<int, int> breakdown;

  bool get isRated => total > 0;

  /// The share of reviews at [star], 0 when nothing is rated. Used for the
  /// bars, which are otherwise a division by zero.
  double shareAt(int star) {
    if (total <= 0) return 0;
    return (breakdown[star] ?? 0) / total;
  }

  int countAt(int star) => breakdown[star] ?? 0;

  factory ProviderRating.fromJson(Map<String, dynamic> json) {
    return ProviderRating(
      average: (json['average'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toInt() ?? 0,
      breakdown: _breakdownOf(json['breakdown']),
    );
  }

  /// The endpoint keys the breakdown by star as a string — "1" through "5".
  /// Anything that is not a number is skipped rather than guessed at.
  static Map<int, int> _breakdownOf(Object? raw) {
    if (raw is! Map) return const {};
    final counts = <int, int>{};
    for (final entry in raw.entries) {
      final star = int.tryParse('${entry.key}');
      if (star == null) continue;
      counts[star] = (entry.value as num?)?.toInt() ?? 0;
    }
    return counts;
  }

  static const empty = ProviderRating(average: 0, total: 0, breakdown: {});

  @override
  List<Object?> get props => [average, total, breakdown];
}

/// One service on the provider's list.
class ProviderServiceItem extends Equatable {
  const ProviderServiceItem({
    required this.id,
    required this.name,
    required this.fromPricePaise,
    this.description,
    this.unit,
    this.categoryId,
    this.visible = true,
    this.status = '',
  });

  final int id;
  final String name;

  /// Null on every service the dev backend returns; the row leaves the line
  /// out rather than filling it.
  final String? description;

  final int fromPricePaise;

  /// "per unit" / "per visit".
  final String? unit;

  final int? categoryId;
  final bool visible;

  /// "ACTIVE". Anything else is not offered.
  final String status;

  bool get isOffered => visible && status.toUpperCase() == 'ACTIVE';

  factory ProviderServiceItem.fromJson(Map<String, dynamic> json) {
    return ProviderServiceItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      fromPricePaise: (json['fromPricePaise'] as num?)?.toInt() ?? 0,
      unit: json['unit'] as String?,
      categoryId: (json['categoryId'] as num?)?.toInt(),
      visible: json['visible'] as bool? ?? true,
      status: json['status'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, fromPricePaise, unit, status, visible];
}

/// One product in the provider's store.
class ProviderProductItem extends Equatable {
  const ProviderProductItem({
    required this.id,
    required this.name,
    required this.pricePaise,
    required this.stockCount,
    this.description,
    this.imageFileId,
    this.categoryId,
    this.visible = true,
    this.status = '',
  });

  final int id;
  final String name;
  final String? description;
  final int pricePaise;

  /// Zero means out of stock, which the card says.
  final int stockCount;

  /// Null on everything the dev backend returns, and there is no endpoint
  /// that turns one into an image — so the card draws no picture rather than
  /// a placeholder pretending to be one.
  final String? imageFileId;

  final int? categoryId;
  final bool visible;
  final String status;

  bool get isInStock => stockCount > 0;
  bool get isOffered => visible && status.toUpperCase() == 'ACTIVE';

  factory ProviderProductItem.fromJson(Map<String, dynamic> json) {
    return ProviderProductItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      pricePaise: (json['pricePaise'] as num?)?.toInt() ?? 0,
      stockCount: (json['stockCount'] as num?)?.toInt() ?? 0,
      imageFileId: json['imageFileId'] as String?,
      categoryId: (json['categoryId'] as num?)?.toInt(),
      visible: json['visible'] as bool? ?? true,
      status: json['status'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, name, pricePaise, stockCount, status];
}

/// One day of the week's opening hours.
class ProviderAvailabilityDay extends Equatable {
  const ProviderAvailabilityDay({
    required this.dayOfWeek,
    required this.dayName,
    required this.closed,
    this.opensAt,
    this.closesAt,
  });

  /// 1 is Monday through 7 for Sunday, as the endpoint numbers them.
  final int dayOfWeek;
  final String dayName;

  /// True even on a day that still carries times — Sunday comes back with
  /// 09:00–19:00 and `closed: true`, and closed is what counts.
  final bool closed;

  final String? opensAt;
  final String? closesAt;

  /// "09:00 – 19:00", or "Closed". The seconds the server sends are dropped
  /// because nobody reads a shop's hours to the second.
  String get hoursLabel {
    if (closed) return 'Closed';
    final opens = _hhmm(opensAt);
    final closes = _hhmm(closesAt);
    if (opens.isEmpty || closes.isEmpty) return '—';
    return '$opens – $closes';
  }

  static String _hhmm(String? raw) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) return '';
    final parts = value.split(':');
    if (parts.length < 2) return value;
    return '${parts[0]}:${parts[1]}';
  }

  factory ProviderAvailabilityDay.fromJson(Map<String, dynamic> json) {
    return ProviderAvailabilityDay(
      dayOfWeek: (json['dayOfWeek'] as num?)?.toInt() ?? 0,
      dayName: json['dayName'] as String? ?? '',
      closed: json['closed'] as bool? ?? false,
      opensAt: json['opensAt'] as String?,
      closesAt: json['closesAt'] as String?,
    );
  }

  @override
  List<Object?> get props => [dayOfWeek, dayName, closed, opensAt, closesAt];
}

/// The provider's profile, as `/api/v1/user/providers/{slug}` returns it.
class ProviderDetail extends Equatable {
  const ProviderDetail({
    required this.providerId,
    required this.slug,
    required this.name,
    required this.rating,
    this.about,
    this.businessType,
    this.entityKind,
    this.logoFileId,
    this.coverFileId,
    this.addressLine,
    this.homeLocality,
    this.coverage = const [],
    this.categories = const [],
    this.openNow = false,
    this.homeService = false,
    this.responseTimeMinutes,
    this.verified = false,
    this.services = const [],
    this.products = const [],
    this.availability = const [],
    this.saved = false,
  });

  final String providerId;
  final String slug;
  final String name;

  /// Their own words. Null when they have written none, and then the About
  /// tab leaves the paragraph out rather than writing one for them.
  final String? about;

  /// "BOTH" / "SERVICE" / "PRODUCT" — whether they do jobs, sell parts, or
  /// both. Kept as the server's own word.
  final String? businessType;

  /// "SHOP" / "INDIVIDUAL".
  final String? entityKind;

  /// Both null on everything the dev backend returns, and no endpoint turns
  /// a file id into a URL — so nothing draws them yet.
  final String? logoFileId;
  final String? coverFileId;

  final String? addressLine;

  final ProviderLocality? homeLocality;
  final List<ProviderLocality> coverage;
  final List<ProviderCategory> categories;

  final bool openNow;

  /// Whether they come to the seeker.
  final bool homeService;

  /// Null when the server sends none.
  final int? responseTimeMinutes;

  final bool verified;
  final ProviderRating rating;

  final List<ProviderServiceItem> services;
  final List<ProviderProductItem> products;
  final List<ProviderAvailabilityDay> availability;

  /// Whether this seeker has saved them.
  final bool saved;

  /// "Electrician · Appliance Repair" — the trades, joined.
  String get tradeLine =>
      categories.map((category) => category.tradeName).join(' · ');

  /// Up to two letters for the avatar. There is no logo to draw: the file id
  /// is null and nothing resolves one into an image.
  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  factory ProviderDetail.fromJson(Map<String, dynamic> json) {
    List<T> listOf<T>(String key, T Function(Map<String, dynamic>) parse) {
      final raw = json[key];
      return [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map) parse(Map<String, dynamic>.from(entry)),
      ];
    }

    final home = json['homeLocality'];
    final rating = json['rating'];

    return ProviderDetail(
      providerId: json['providerId'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      about: json['about'] as String?,
      businessType: json['businessType'] as String?,
      entityKind: json['entityKind'] as String?,
      logoFileId: json['logoFileId'] as String?,
      coverFileId: json['coverFileId'] as String?,
      addressLine: json['addressLine'] as String?,
      homeLocality: home is Map
          ? ProviderLocality.fromJson(Map<String, dynamic>.from(home))
          : null,
      coverage: listOf('coverage', ProviderLocality.fromJson),
      categories: listOf('categories', ProviderCategory.fromJson),
      openNow: json['openNow'] as bool? ?? false,
      homeService: json['homeService'] as bool? ?? false,
      responseTimeMinutes: (json['responseTimeMinutes'] as num?)?.toInt(),
      verified: json['verified'] as bool? ?? false,
      rating: rating is Map
          ? ProviderRating.fromJson(Map<String, dynamic>.from(rating))
          : ProviderRating.empty,
      services: listOf('services', ProviderServiceItem.fromJson),
      products: listOf('products', ProviderProductItem.fromJson),
      availability: listOf('availability', ProviderAvailabilityDay.fromJson),
      saved: json['saved'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    providerId,
    slug,
    name,
    about,
    businessType,
    entityKind,
    addressLine,
    homeLocality,
    coverage,
    categories,
    openNow,
    homeService,
    responseTimeMinutes,
    verified,
    rating,
    services,
    products,
    availability,
    saved,
  ];
}

/// One page of `/api/v1/user/providers/{slug}/reviews`.
///
/// The envelope is modelled from the response; the shape of an item is not.
/// Every reviews response the dev backend returns has `items: []`, so there
/// is nothing to read a review's fields from — they are kept as the raw maps
/// the server sent, and the tab draws the rating summary and its zero state
/// until a real one can be seen.
class ProviderReviewPage extends Equatable {
  const ProviderReviewPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
  });

  final List<Map<String, dynamic>> items;
  final int page;
  final int size;
  final int totalItems;
  final int totalPages;
  final bool hasNext;

  bool get isEmpty => items.isEmpty;

  const ProviderReviewPage.empty()
    : items = const [],
      page = 0,
      size = 0,
      totalItems = 0,
      totalPages = 0,
      hasNext = false;

  factory ProviderReviewPage.fromJson(Map<String, dynamic> json) {
    final raw = json['items'];
    return ProviderReviewPage(
      items: [
        if (raw is List)
          for (final entry in raw)
            if (entry is Map) Map<String, dynamic>.from(entry),
      ],
      page: (json['page'] as num?)?.toInt() ?? 0,
      size: (json['size'] as num?)?.toInt() ?? 0,
      totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
      totalPages: (json['totalPages'] as num?)?.toInt() ?? 0,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [items, page, size, totalItems, totalPages];
}
