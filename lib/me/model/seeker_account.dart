import 'package:equatable/equatable.dart';

import 'package:local_markerplace/me/model/kyc_document.dart';

/// The signed-in seeker, as the Me screen shows them.
class SeekerAccount extends Equatable {
  const SeekerAccount({
    required this.name,
    required this.phone,
    required this.localityName,
    required this.joined,
    required this.bookedOrders,
    required this.unreadChats,
    required this.savedProviderCount,
    this.savedAddressCount,
    required this.interests,
    required this.kycStatus,
  });

  final String name;

  /// Formatted for display, e.g. "+91 98765 43210".
  final String phone;

  final String localityName;

  /// "joined Aug 2026".
  final String joined;

  /// How many bookings the seeker has, for the "My orders" row. Real
  /// session state rather than a figure typed into the view.
  final int bookedOrders;
  final int unreadChats;
  final int savedProviderCount;
  /// Null until the addresses endpoint has answered — the Me row shows a
  /// dash rather than claiming zero for a seeker whose addresses have simply
  /// not been fetched yet.
  final int? savedAddressCount;

  /// Category labels the seeker picked, in the order Edit profile shows them.
  final List<String> interests;

  /// Rolled up from their documents: what the Me row's pill says.
  final KycStatus kycStatus;

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  /// "Ajnara Gen X · joined Aug 2026".
  String get subtitle => '$localityName · $joined';

  @override
  List<Object?> get props => [
    name,
    phone,
    localityName,
    joined,
    bookedOrders,
    unreadChats,
    savedProviderCount,
    savedAddressCount,
    interests,
    kycStatus,
  ];
}
