import 'package:equatable/equatable.dart';

/// An address the seeker has saved for visits and deliveries.
///
/// The endpoint keeps the parts separate — house, street, landmark, area,
/// pincode — and the design draws two lines, so the joining is done here
/// rather than in the card: every screen that shows an address should break
/// it the same way, and a null in the middle should close up rather than
/// leave a stray comma.
class SavedAddress extends Equatable {
  const SavedAddress({
    required this.label,
    this.id,
    this.line1 = '',
    this.line2,
    this.landmark,
    this.localitySlug = '',
    this.localityName = '',
    this.pincode = '',
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  /// The server's id, and what a later edit or delete will name. Null for
  /// anything built locally.
  final int? id;

  /// "Home", "Office", "Mum".
  final String label;

  /// House or flat — "Tower B, Flat 1204".
  final String line1;

  /// Street or block. Often absent.
  final String? line2;

  /// "Opposite the community hall". Often absent.
  final String? landmark;

  /// The area, as the rest of the app spells it: the slug is what home and
  /// search match on, the name is what the seeker reads.
  final String localitySlug;
  final String localityName;

  final String pincode;

  /// Where the pin was dropped, when it was. Null for a typed address.
  final double? lat;
  final double? lng;

  final bool isDefault;

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] as int?,
      label: (json['label'] as String? ?? '').trim(),
      line1: (json['line1'] as String? ?? '').trim(),
      line2: _trimmedOrNull(json['line2']),
      landmark: _trimmedOrNull(json['landmark']),
      localitySlug: (json['localitySlug'] as String? ?? '').trim(),
      localityName: (json['localityName'] as String? ?? '').trim(),
      pincode: (json['pincode'] as String? ?? '').trim(),
      lat: _toDouble(json['lat']),
      lng: _toDouble(json['lng']),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  /// Blank is the same as absent for a line the card would otherwise draw an
  /// empty row for.
  static String? _trimmedOrNull(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Coordinates come back as JSON numbers, which is an int when the server
  /// has no fraction to send.
  static double? _toDouble(Object? value) => switch (value) {
    final double value => value,
    final int value => value.toDouble(),
    final String value => double.tryParse(value),
    _ => null,
  };

  /// What is shown on top: the address as it would be written on an envelope,
  /// before the area.
  String get street =>
      [line1, line2, landmark].where(_isSaid).join(', ');

  /// What is shown under it: the area and its pincode.
  String get area => [localityName, pincode].where(_isSaid).join(', ');

  /// The address as the card draws it, already broken where the design
  /// breaks it.
  String get lines => [street, area].where(_isSaid).join('\n');

  static bool _isSaid(String? part) => part != null && part.isNotEmpty;

  /// Falls back to the area, because an address with no label of its own is
  /// still somewhere — a blank heading would read as a broken row.
  String get displayLabel => label.isNotEmpty
      ? label
      : (localityName.isNotEmpty ? localityName : 'Saved address');

  SavedAddress copyWith({
    int? id,
    String? label,
    String? line1,
    String? line2,
    String? landmark,
    String? localitySlug,
    String? localityName,
    String? pincode,
    double? lat,
    double? lng,
    bool? isDefault,
  }) {
    return SavedAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      line1: line1 ?? this.line1,
      line2: line2 ?? this.line2,
      landmark: landmark ?? this.landmark,
      localitySlug: localitySlug ?? this.localitySlug,
      localityName: localityName ?? this.localityName,
      pincode: pincode ?? this.pincode,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  List<Object?> get props => [
    id,
    label,
    line1,
    line2,
    landmark,
    localitySlug,
    localityName,
    pincode,
    lat,
    lng,
    isDefault,
  ];
}
