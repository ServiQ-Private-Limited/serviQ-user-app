import 'dart:async';

import 'package:local_markerplace/me/repository/address_repository.dart';
import 'package:local_markerplace/store/model/cart_product.dart';
import 'package:local_markerplace/visit/model/visit.dart';
import 'package:local_markerplace/visit/model/visit_mode.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/model/visit_slot.dart';

/// The carts the seeker is filling, and the visits booked out of them.
///
/// There is a cart per provider, not one cart. A visit is still one provider
/// making one trip — that has not changed — but a seeker shopping the
/// society will pick a filter up from one store and book a carpenter from
/// another, and being told the second replaced the first was wrong. So the
/// carts sit side by side and are checked out together.
///
/// [carts] is ordered by what was touched last, which is what the bar above
/// the tabs shows and what "Your carts" lists first.
class VisitRepository {
  VisitRepository();

  static final VisitRepository shared = VisitRepository();

  /// Announced whenever a cart changes.
  ///
  /// A cart is added to from the provider's page, emptied from its own
  /// screen and booked from the checkout, while the bar above the tabs has
  /// to say the truth on all of them. Reading the store as the bar built
  /// itself is what used to keep it honest; this is what keeps it honest now
  /// that a bloc holds what it draws.
  Stream<void> get changes => _changes.stream;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _announce() {
    if (!_changes.isClosed) _changes.add(null);
  }

  final List<Visit> _carts = <Visit>[];

  /// Every cart, most recently touched first.
  List<Visit> get carts => List.unmodifiable(_carts);

  /// The cart the bar speaks for — the one last added to. Null when there
  /// are none.
  Visit? get current => _carts.isEmpty ? null : _carts.first;

  /// That provider's cart, or null if they have none.
  Visit? cartFor(String providerName) {
    for (final cart in _carts) {
      if (cart.providerName == providerName) return cart;
    }
    return null;
  }

  bool get isEmpty => _carts.isEmpty;

  int get cartCount => _carts.length;

  /// Services and parts across every cart, which is what "4 items" counts.
  int get itemCount =>
      _carts.fold(0, (sum, cart) => sum + cart.serviceCount + cart.partCount);

  /// What every cart comes to together, before any of them is timed.
  double get grandTotal =>
      _carts.fold(0, (sum, cart) => sum + cart.servicesTotal + cart.partsTotal);

  /// Every cart that has a time on it and could be booked now.
  List<Visit> get readyCarts => _carts.where((cart) => cart.isReady).toList();

  /// Visits that have been confirmed this session, newest first.
  final List<Visit> booked = <Visit>[];

  int _indexOf(String providerName) =>
      _carts.indexWhere((cart) => cart.providerName == providerName);

  /// Puts [cart] at the front — the bar names whichever was touched last.
  void _promote(Visit cart, int at) {
    _carts.removeAt(at);
    _carts.insert(0, cart);
  }

  Visit _cartOrNew(
    String providerName,
    String providerLine,
    bool isVerifiedProvider,
  ) =>
      cartFor(providerName) ??
      Visit(
        providerName: providerName,
        providerLine: providerLine,
        isVerifiedProvider: isVerifiedProvider,
        addressLabel: _defaultAddressLabel,
        addressLine: _defaultAddressLine,
      );

  /// The seeker's default saved address, as the visit screens show it.
  ///
  /// Read at the moment a visit is started rather than held, so a seeker who
  /// saves an address and comes back gets it on the next one.
  static String? get _defaultAddressLabel =>
      AddressRepository.shared.defaultAddress?.displayLabel;

  /// The whole address on one line, area and pincode included.
  ///
  /// The street alone is not enough to tell two saved addresses apart — an
  /// account with twenty of them reading "A-1" would leave the seeker
  /// guessing which one the provider is being sent to.
  static String? get _defaultAddressLine {
    final address = AddressRepository.shared.defaultAddress;
    if (address == null) return null;
    return address.lines.replaceAll('\n', ', ');
  }

  /// Fills in the address on a cart that was started before the seeker's
  /// addresses had arrived.
  ///
  /// A cart is stamped when it is opened, which is usually after the list has
  /// loaded — but a seeker who adds a service in the first moment after
  /// launch would otherwise book a visit with nowhere to go, having saved an
  /// address all along.
  static Visit _withAddress(Visit visit) {
    if (visit.hasAddress) return visit;
    final line = _defaultAddressLine;
    if (line == null) return visit;
    return visit.copyWith(
      addressLabel: _defaultAddressLabel,
      addressLine: line,
    );
  }

  /// Adds [service] to that provider's cart, starting one if they have none.
  ///
  /// Nothing is ever replaced: another provider means another cart.
  void addService({
    required String providerName,
    required String providerLine,
    required VisitService service,
    bool isVerifiedProvider = true,
  }) {
    final existing = _cartOrNew(providerName, providerLine, isVerifiedProvider);
    // The same service added twice becomes one line with a bigger count,
    // which is what the stepper on the sheet is really editing.
    final services = [...existing.services];
    final index = services.indexWhere((s) => s.name == service.name);
    if (index == -1) {
      services.add(service);
    } else {
      services[index] = services[index].copyWith(
        quantity: services[index].quantity + service.quantity,
        note: service.note.isEmpty ? services[index].note : service.note,
      );
    }
    _put(existing.copyWith(services: services));
  }

  /// Adds a part from the provider's store to the same cart their services
  /// are in — one provider, one trip, one cart.
  void addProduct({
    required String providerName,
    required String providerLine,
    required CartProduct product,
    bool isVerifiedProvider = true,
  }) {
    final existing = _cartOrNew(providerName, providerLine, isVerifiedProvider);
    final parts = [...existing.parts];
    final index = parts.indexWhere((part) => part.name == product.name);
    if (index == -1) {
      parts.add(product);
    } else {
      parts[index] = parts[index].copyWith(
        quantity: parts[index].quantity + product.quantity,
      );
    }
    _put(existing.copyWith(parts: parts));
  }

  /// Writes a cart back, dropping it if it has been emptied and moving it to
  /// the front otherwise.
  void _put(Visit cart) {
    final at = _indexOf(cart.providerName);
    if (cart.services.isEmpty && cart.parts.isEmpty) {
      if (at != -1) _carts.removeAt(at);
      _announce();
      return;
    }
    if (at == -1) {
      _carts.insert(0, cart);
    } else {
      _carts[at] = cart;
      _promote(cart, at);
    }
    _announce();
  }

  // --- editing one provider's cart -----------------------------------------
  //
  // Every one of these names the provider: with several carts open there is
  // no such thing as "the" cart to edit.

  void setPartQuantityAt(String providerName, int index, int quantity) {
    final existing = cartFor(providerName);
    if (existing == null) return;
    if (quantity < 1) return removePartAt(providerName, index);
    final parts = [...existing.parts];
    parts[index] = parts[index].copyWith(quantity: quantity);
    _put(existing.copyWith(parts: parts));
  }

  void removePartAt(String providerName, int index) {
    final existing = cartFor(providerName);
    if (existing == null) return;
    _put(existing.copyWith(parts: [...existing.parts]..removeAt(index)));
  }

  /// Changes how many of a service are wanted. Below one the line goes,
  /// which is how the cart's stepper removes it.
  void setQuantityAt(String providerName, int index, int quantity) {
    final existing = cartFor(providerName);
    if (existing == null) return;
    if (quantity < 1) return removeServiceAt(providerName, index);
    final services = [...existing.services];
    services[index] = services[index].copyWith(quantity: quantity);
    _put(existing.copyWith(services: services));
  }

  void removeServiceAt(String providerName, int index) {
    final existing = cartFor(providerName);
    if (existing == null) return;
    _put(existing.copyWith(services: [...existing.services]..removeAt(index)));
  }

  void setMode(String providerName, VisitMode mode) {
    final existing = cartFor(providerName);
    if (existing == null) return;
    // An instant visit has no slot; keeping a stale one would confirm a time
    // the seeker is no longer asking for.
    _put(existing.copyWith(mode: mode, clearSlot: !mode.needsSlot));
  }

  /// Picking a time is itself the choice of a scheduled visit.
  void setSlot(String providerName, VisitSlot slot) {
    final existing = cartFor(providerName);
    if (existing == null) return;
    _put(existing.copyWith(mode: VisitMode.scheduled, slot: slot));
  }

  void setPayment(String providerName, VisitPayment payment) {
    final existing = cartFor(providerName);
    if (existing == null) return;
    _put(existing.copyWith(payment: payment));
  }

  /// Throws away one provider's cart — the × beside them in "Your carts".
  void removeCart(String providerName) {
    final at = _indexOf(providerName);
    if (at != -1) _carts.removeAt(at);
    _announce();
  }

  /// "Clear all".
  void clear() {
    _carts.clear();
    _announce();
  }

  /// Books a visit straight from an accepted offer.
  ///
  /// Nothing is chosen here: the provider named a price and a time when they
  /// offered, and taking the offer agreed to both — so this skips the
  /// picker and the confirm screen and lands in [booked] already done. It
  /// deliberately leaves [current] alone, because a seeker part-way through
  /// building a visit with somebody else should not lose it by accepting an
  /// offer from a third party.
  Visit bookFromOffer({
    required String providerName,
    required String providerLine,
    required VisitService service,
    required String agreedWhen,
    bool isVerifiedProvider = true,
  }) {
    final confirmed = Visit(
      providerName: providerName,
      providerLine: providerLine,
      isVerifiedProvider: isVerifiedProvider,
      services: [service],
      agreedWhen: agreedWhen,
      reference: _nextReference(),
      addressLabel: _defaultAddressLabel,
      addressLine: _defaultAddressLine,
    );
    booked.insert(0, confirmed);
    return confirmed;
  }

  /// Books one provider's cart and hands back the confirmed copy.
  Visit confirm(String providerName) {
    final existing = _withAddress(cartFor(providerName)!);
    final confirmed = existing.copyWith(reference: _nextReference());
    booked.insert(0, confirmed);
    removeCart(providerName);
    _announce();
    return confirmed;
  }

  /// Books every cart that has a time on it, oldest first so the references
  /// run in the order they were filled.
  ///
  /// Carts still missing a time are left where they are rather than being
  /// booked into nothing.
  List<Visit> confirmAll() {
    final confirmed = <Visit>[];
    for (final cart in _carts.reversed.toList()) {
      if (!cart.isReady) continue;
      confirmed.add(confirm(cart.providerName));
    }
    return confirmed;
  }

  int _sequence = 4820;

  String _nextReference() => 'SQ-${++_sequence}';

  /// Whether an instant visit can be placed right now.
  ///
  /// There is no dispatcher to ask yet, so this is simply true; the cart
  /// draws the design's "instant unavailable" state from it, which is what a
  /// real answer would switch off.
  bool instantAvailable = true;

  /// The next three days, each with its half-hour start times.
  ///
  /// A few are marked taken so the grid shows what a busy day looks like; a
  /// real endpoint would say which are actually free.
  List<VisitDay> days({int count = 3}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return [
      for (var offset = 0; offset < count; offset++)
        () {
          final date = today.add(Duration(days: offset));
          return VisitDay(
            date: date,
            slots: [
              for (var half = 13; half <= 42; half++)
                VisitSlot(
                  startHour: half ~/ 2,
                  startMinute: half.isEven ? 0 : 30,
                  date: date,
                  // Starts already gone: a scattering the provider has
                  // taken, and anything already past on today's date.
                  isFree:
                      half % 7 != 6 && !(offset == 0 && half ~/ 2 <= now.hour),
                ),
            ],
          );
        }(),
    ];
  }
}
