import 'package:equatable/equatable.dart';

/// Where the professional is going and who they are meeting there.
class BookingDetails extends Equatable {
  /// The seeker's default saved address, as one line.
  ///
  /// Null when they have saved none — which the card says, rather than
  /// printing an address nobody lives at. It used to carry a written-in
  /// Indirapuram address that every cart showed regardless of whose it was.
  final String? address;

  final String customerName;
  final String customerPhone;

  const BookingDetails({
    this.address,
    required this.customerName,
    required this.customerPhone,
  });

  bool get hasAddress => address != null && address!.isNotEmpty;

  /// What the row reads when no address has been chosen — whether because
  /// none is saved or because none of the saved ones is the default.
  String get addressLine =>
      hasAddress ? address! : 'Choose where the professional should come.';

  String get addressTitle => hasAddress ? 'Location' : 'No address chosen';

  @override
  List<Object?> get props => [address, customerName, customerPhone];
}
