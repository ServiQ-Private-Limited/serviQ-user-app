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

  /// What the row reads when there is nowhere to send anybody yet.
  String get addressLine =>
      hasAddress ? address! : 'Add one so the professional knows where to come.';

  String get addressTitle => hasAddress ? 'Location' : 'No address saved';

  @override
  List<Object?> get props => [address, customerName, customerPhone];
}
