import 'package:dartz/dartz.dart';
import 'package:local_markerplace/cart/model/booking_details.dart';
import 'package:local_markerplace/cart/model/cart_item.dart';
import 'package:local_markerplace/cart/model/cart_slot.dart';
import 'package:local_markerplace/dashboard/model/services.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';
import 'package:local_markerplace/network/failure.dart';

/// Everything the cart needs from the backend: what the chosen services cost
/// once offers are applied, when a professional can come, and where they are
/// going.
class CartRepository {
  const CartRepository();

  /// Share of the list price the customer pays under the current promotion.
  ///
  /// TODO: offers are per service and come from the pricing API; this flat
  /// rate stands in until that exists.
  static const double _offerRate = 0.4;

  /// How many days ahead a visit can be booked, counting today.
  static const int slotDayCount = 4;

  /// First and last slot of a working day, and the gap between slots.
  static const int _firstSlotHour = 8;
  static const int _lastSlotHour = 21;
  static const int _slotStepMinutes = 30;

  /// A slot needs this much lead time, so today's next hour is not offered.
  static const Duration _leadTime = Duration(minutes: 60);

  /// Turns the services picked on the dashboard into priced cart lines.
  ///
  /// The dashboard only knows a service's list price, so the offer is applied
  /// here — pricing is the server's business, not the selection screen's.
  Future<Either<Failure, List<CartItem>>> getCartItems(
    List<ServiceDetails> services,
  ) async {
    // TODO: replace with a real API call (e.g. POST /cart with service ids).
    await Future.delayed(const Duration(milliseconds: 600));

    final items = <CartItem>[];
    for (final service in services) {
      final listPrice = double.tryParse(service.price) ?? 0;
      items.add(
        CartItem(
          id: 'cart-${service.title.toLowerCase().replaceAll(' ', '-')}',
          title: service.title,
          imageUrl: service.imageUrl,
          price: (listPrice * _offerRate).roundToDouble(),
          originalPrice: listPrice,
        ),
      );
    }
    return Right(items);
  }

  /// The next [slotDayCount] days of start times, today first.
  Future<Either<Failure, List<CartSlotDay>>> getSlotDays() async {
    // TODO: replace with a real API call (e.g. GET /slots?days=4).
    await Future.delayed(const Duration(milliseconds: 600));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final earliest = now.add(_leadTime);

    final days = <CartSlotDay>[];
    for (int dayOffset = 0; dayOffset < slotDayCount; dayOffset++) {
      final date = today.add(Duration(days: dayOffset));
      final slots = <CartSlot>[];
      DateTime start = date.add(const Duration(hours: _firstSlotHour));
      final dayEnd = date.add(const Duration(hours: _lastSlotHour));

      while (!start.isAfter(dayEnd)) {
        slots.add(
          CartSlot(
            id: 'slot-${start.millisecondsSinceEpoch}',
            startTime: start,
            // Past and too-soon slots are gone, and a couple of stand-in
            // bookings keep the day from looking suspiciously empty.
            isAvailable:
                start.isAfter(earliest) &&
                !(dayOffset == 1 && start.hour == 13) &&
                !(dayOffset == 2 && start.hour == 17),
          ),
        );
        start = start.add(const Duration(minutes: _slotStepMinutes));
      }
      days.add(CartSlotDay(date: date, slots: slots));
    }
    return Right(days);
  }

  /// Whether a professional can be dispatched right now.
  ///
  /// When this is false the cart keeps the Instant tab visible but explains
  /// why it cannot be used, rather than hiding the option entirely.
  Future<Either<Failure, bool>> isInstantAvailable() async {
    // TODO: replace with a real API call (e.g. GET /availability/instant).
    await Future.delayed(const Duration(milliseconds: 400));
    return const Right(true);
  }

  /// The saved address and contact the booking will use.
  ///
  /// The address is the seeker's own, read from `/api/v1/user/addresses`, and
  /// is absent rather than invented when they have saved none.
  Future<Either<Failure, BookingDetails>> getBookingDetails() async {
    final addresses = AddressRepository.shared;
    // Only fetched when nothing has been loaded yet: coming to the cart from
    // the addresses screen should not ask the server twice.
    if (addresses.count == null) await addresses.refreshCount();
    final address = addresses.defaultAddress;

    return Right(
      BookingDetails(
        address: address == null ? null : address.lines.replaceAll('\n', ', '),
        // TODO: the contact is still seeded — the name and number the
        // professional would be given are not yet read from the signed-in
        // account, only the address is.
        customerName: 'Chakori',
        customerPhone: '+91 8527917303',
      ),
    );
  }
}
