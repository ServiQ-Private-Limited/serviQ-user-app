import 'package:equatable/equatable.dart';

/// A place the seeker has pointed at, on its way to becoming a saved address.
///
/// The two steps of the flow each own half of this: the map step fixes where
/// it is, the details step says what it is called and which door to knock on.
/// It is not a [SavedAddress] until the server has one.
class AddressDraft extends Equatable {
  const AddressDraft({
    required this.latitude,
    required this.longitude,
    this.placeName = '',
    this.formattedAddress = '',
    this.pincode = '',
  });

  final double latitude;
  final double longitude;

  /// "Shakti Khand" — the neighbourhood the pin landed in, which heads the
  /// confirmation.
  final String placeName;

  /// "766, Shakti Khand, Shakti Khand 4, Indirapuram, Ghaziabad, Uttar
  /// Pradesh 201014, India" — the whole thing as the geocoder reads it back.
  final String formattedAddress;

  /// "201014". The geocoder knows it, so the seeker is not asked to type a
  /// number the map already established — and an address saved without one
  /// is an address nobody can post to.
  final String pincode;

  /// True once the pin has an address to show for itself.
  ///
  /// A pin with no address yet is a pin the seeker cannot confirm: they would
  /// be saying yes to a dot rather than to a place.
  bool get isResolved => formattedAddress.isNotEmpty;

  AddressDraft copyWith({
    double? latitude,
    double? longitude,
    String? placeName,
    String? formattedAddress,
    String? pincode,
  }) {
    return AddressDraft(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeName: placeName ?? this.placeName,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      pincode: pincode ?? this.pincode,
    );
  }

  @override
  List<Object?> get props => [
    latitude,
    longitude,
    placeName,
    formattedAddress,
    pincode,
  ];
}

/// The labels the design offers before the seeker types their own.
const addressLabelSuggestions = <String>[
  'Home',
  'Office',
  'PG',
  'Chill Spot',
  'Gym',
];
