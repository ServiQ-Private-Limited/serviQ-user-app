import 'package:equatable/equatable.dart';

import 'package:local_markerplace/store/model/cart_product.dart';
import 'package:local_markerplace/visit/model/visit_mode.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/model/visit_slot.dart';

/// How the seeker settles up once the work is done.
enum VisitPayment {
  upiAfterService(
    'UPI after service',
    'Pay when the job is done',
    'UPI after service',
  ),
  cash('Cash', 'Hand it to the provider', 'cash');

  const VisitPayment(this.label, this.detail, this.receiptLabel);

  final String label;
  final String detail;

  /// How the receipt says it, after "Pay by". Lower-casing [label] would
  /// turn UPI into "upi".
  final String receiptLabel;
}

/// One provider, one trip, one slot — the design's words, and the reason
/// this is a visit rather than a cart. Services accumulate against a single
/// provider; choosing a different one starts a new visit.
class Visit extends Equatable {
  const Visit({
    required this.providerName,
    required this.providerLine,
    this.services = const [],
    this.parts = const [],
    this.mode,
    this.slot,
    this.addressLabel,
    this.addressLine,
    this.contactName = 'Test Seeker',
    this.contactPhone = '+91 98765 43210',
    this.payment = VisitPayment.upiAfterService,
    this.reference,
    this.agreedWhen,
    this.isVerifiedProvider = true,
  });

  final String providerName;

  /// "Ajnara Gen X · usually replies in 10 min".
  final String providerLine;

  final List<VisitService> services;

  /// Parts bought from the same provider's store. They ride along with the
  /// visit rather than being a second errand — one provider, one trip, one
  /// cart, which is why they live here and not in a store of their own.
  final List<CartProduct> parts;

  /// Null until the seeker picks one, which is what the design gates
  /// continuing on.
  final VisitMode? mode;

  /// Only meaningful on a scheduled visit.
  final VisitSlot? slot;

  /// Where the provider is going, taken from the seeker's saved addresses.
  ///
  /// Null when they have none saved — which the screens say, rather than
  /// printing an address nobody lives at. It used to default to a written-in
  /// "Tower B, Flat 1204, Crossings Republik", which every booking then
  /// showed regardless of whose account it was.
  final String? addressLabel;
  final String? addressLine;

  /// True when there is an address to send somebody to.
  bool get hasAddress => addressLine != null && addressLine!.isNotEmpty;

  /// The heading the address is shown under, and the line beneath it.
  ///
  /// Both say the same thing when nothing is saved, so a seeker cannot get
  /// as far as a booking without noticing that nobody knows where to come.
  String get addressTitle => hasAddress
      ? (addressLabel?.isNotEmpty == true ? addressLabel! : 'Your address')
      : 'No address saved';

  String get addressSubtitle =>
      hasAddress ? addressLine! : 'Add one so the provider knows where to come.';

  /// The one-line form the receipt and the order list use.
  String get addressSummary => hasAddress
      ? (addressLabel?.isNotEmpty == true
            ? '$addressLine · $addressLabel'
            : addressLine!)
      : 'No address saved';

  /// Who the provider calls on the day. Seeded like the address is, until
  /// the account is wired through.
  final String contactName;
  final String contactPhone;

  final VisitPayment payment;

  /// "SQ-4821", assigned when the visit is confirmed.
  final String? reference;

  /// When the provider said they would come, in their own words — "today,
  /// 4 – 6 pm".
  ///
  /// Set only on a visit that came from an accepted offer. There was no slot
  /// to pick there: the provider named a time when they offered and the
  /// seeker agreed to it by taking the offer, so the visit arrives already
  /// timed and does not go through the picker.
  final String? agreedWhen;

  final bool isVerifiedProvider;

  /// The visit charge the design shows and then waives. It is quoted so the
  /// seeker knows it was waived rather than never existing.
  static const double visitCharge = 99;

  double get servicesTotal =>
      services.fold(0, (sum, service) => sum + service.lineTotal);

  double get partsTotal => parts.fold(0, (sum, part) => sum + part.lineTotal);

  /// Parts are counted by the piece, so two filters are two items.
  int get partCount => parts.fold(0, (sum, part) => sum + part.quantity);

  double get instantFee =>
      mode == VisitMode.instant ? VisitMode.instant.fee.toDouble() : 0;

  /// What the seeker is told to expect. The visit charge is waived, so it
  /// never lands here.
  double get estimate => servicesTotal + partsTotal + instantFee;

  int get serviceCount => services.length;

  /// Ready to be confirmed: a mode is chosen, and a scheduled visit has its
  /// slot.
  bool get isReady {
    if (services.isEmpty && parts.isEmpty) return false;
    if (agreedWhen != null) return true;
    final chosen = mode;
    if (chosen == null) return false;
    if (!chosen.needsSlot) return true;
    return slot != null;
  }

  /// "2 services · 1 part · Shahnaz RO & Chimney".
  String get summaryLine => [contentLine, providerName].join(' · ');

  /// "2 services · 1 part" — what is in the cart, without whose it is.
  String get contentLine => [
    if (serviceCount > 0)
      '$serviceCount ${serviceCount == 1 ? 'service' : 'services'}',
    if (partCount > 0) '$partCount ${partCount == 1 ? 'part' : 'parts'}',
  ].join(' · ');

  /// "Tomorrow, 4 Sep · 2 – 4 pm", or the instant wording.
  String get whenLabel {
    final agreed = agreedWhen;
    if (agreed != null) return agreed;
    if (mode == VisitMode.instant) return 'As soon as a provider accepts';
    final chosen = slot;
    if (chosen == null) return 'No slot chosen yet';
    final day = VisitDay(date: chosen.date, slots: const []);
    return '${day.weekdayLabel}, ${day.dateLabel} · ${chosen.spokenLabel}';
  }

  /// "Mon, Sep 7 - 07:00AM" — the booking-details row.
  String? get scheduledForLabel {
    final chosen = slot;
    if (chosen == null) return null;
    final day = VisitDay(date: chosen.date, slots: const []);
    return '${day.shortWeekday}, ${day.monthDayLabel} - '
        '${chosen.compactLabel}';
  }

  Visit copyWith({
    List<VisitService>? services,
    List<CartProduct>? parts,
    VisitMode? mode,
    VisitSlot? slot,
    bool clearSlot = false,
    String? addressLabel,
    String? addressLine,
    VisitPayment? payment,
    String? reference,
  }) => Visit(
    providerName: providerName,
    providerLine: providerLine,
    isVerifiedProvider: isVerifiedProvider,
    agreedWhen: agreedWhen,
    services: services ?? this.services,
    parts: parts ?? this.parts,
    mode: mode ?? this.mode,
    slot: clearSlot ? null : (slot ?? this.slot),
    addressLabel: addressLabel ?? this.addressLabel,
    addressLine: addressLine ?? this.addressLine,
    contactName: contactName,
    contactPhone: contactPhone,
    payment: payment ?? this.payment,
    reference: reference ?? this.reference,
  );

  @override
  List<Object?> get props => [
    providerName,
    providerLine,
    services,
    parts,
    mode,
    slot,
    addressLabel,
    addressLine,
    payment,
    reference,
    agreedWhen,
  ];
}
