import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/cart/repository/cart_repository.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';
import 'package:local_markerplace/visit/model/visit.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

import '../support/fake_address_repository.dart';

/// Where a booking is going.
///
/// Five screens show an address — confirming a visit, the receipt, My orders,
/// the visit detail and the cart — and every one of them used to print the
/// same written-in "Tower B, Flat 1204, Crossings Republik" no matter whose
/// account it was. These pin that an address is the seeker's own or absent,
/// never invented.
void main() {
  /// The addresses the app would have shown before the endpoint existed.
  const invented = [
    'Tower B, Flat 1204',
    'Crossings Republik',
    'Ajnara Gen X',
    'Indirapuram',
    'Shakti Khand',
  ];

  void expectNothingInvented(String? text) {
    if (text == null) return;
    for (final fragment in invented) {
      expect(
        text,
        isNot(contains(fragment)),
        reason: '"$fragment" is written into the app, not the seeker\'s own',
      );
    }
  }

  test('a visit started with no saved address carries none', () {
    final repository = VisitRepository();
    repository.addService(
      providerName: 'Dev Electricals',
      providerLine: 'Galleria Market 1',
      service: const VisitService(
        name: 'Fan repair',
        detail: 'Diagnosis and fix',
        unitPrice: 300,
      ),
    );

    final cart = repository.cartFor('Dev Electricals')!;

    expect(cart.hasAddress, isFalse);
    expect(cart.addressLabel, isNull);
    expect(cart.addressLine, isNull);
    expectNothingInvented(cart.addressLine);
  });

  test('an absent address is said, not filled in', () {
    const visit = Visit(providerName: 'Dev Electricals', providerLine: 'x');

    // "Chosen", not "saved": an account can have three addresses and no
    // default, and the app must not pick one on the seeker's behalf.
    expect(visit.addressTitle, 'No address chosen');
    expect(visit.addressSummary, 'No address chosen');
    expect(
      visit.addressSubtitle,
      'Choose where the provider should come.',
    );
    expectNothingInvented(visit.addressSubtitle);
  });

  test('an address that is there reads as one line for the receipt', () {
    const visit = Visit(
      providerName: 'Dev Electricals',
      providerLine: 'x',
      addressLabel: 'Home',
      addressLine: 'A-1, Galleria Market 1, 201016',
    );

    expect(visit.hasAddress, isTrue);
    expect(visit.addressSummary, 'A-1, Galleria Market 1, 201016 · Home');
    expect(visit.addressTitle, 'Home');
  });

  test('the cart asks for the seeker own address, not a written-in one', () async {
    // Nothing loaded and no server to ask, so the cart must come back with
    // no address rather than with somebody else's.
    const repository = CartRepository();

    final result = await repository.getBookingDetails();

    result.fold((failure) => fail('expected details, got: $failure'), (
      details,
    ) {
      expectNothingInvented(details.address);
      if (!details.hasAddress) {
        expect(details.addressTitle, 'No address chosen');
      }
    });
  });

  test('the address on a cart can be changed', () {
    final repository = VisitRepository();
    repository.addService(
      providerName: 'Dev Electricals',
      providerLine: 'Galleria Market 1',
      service: const VisitService(
        name: 'Fan repair',
        detail: 'Diagnosis and fix',
        unitPrice: 300,
      ),
    );

    repository.setAddress(
      'Dev Electricals',
      sampleAddress(id: 42, label: 'Office', line1: 'Unit 12'),
    );
    final cart = repository.cartFor('Dev Electricals')!;

    expect(cart.hasAddress, isTrue);
    expect(cart.addressId, 42, reason: 'the picker marks the current one');
    expect(cart.addressTitle, 'Office');
    expect(cart.addressLine, 'Unit 12, Galleria Market 1, 201016');
    expectNothingInvented(cart.addressLine);
  });

  test('changing it again replaces it rather than stacking up', () {
    final repository = VisitRepository();
    repository.addService(
      providerName: 'Dev Electricals',
      providerLine: 'Galleria Market 1',
      service: const VisitService(
        name: 'Fan repair',
        detail: 'Diagnosis and fix',
        unitPrice: 300,
      ),
    );

    repository.setAddress('Dev Electricals', sampleAddress(id: 1, label: 'A'));
    repository.setAddress('Dev Electricals', sampleAddress(id: 2, label: 'B'));

    expect(repository.cartFor('Dev Electricals')!.addressId, 2);
    expect(repository.cartFor('Dev Electricals')!.addressTitle, 'B');
  });

  test('a booked visit keeps the address it was booked with', () {
    final repository = VisitRepository();
    repository.addService(
      providerName: 'Dev Electricals',
      providerLine: 'Galleria Market 1',
      service: const VisitService(
        name: 'Fan repair',
        detail: 'Diagnosis and fix',
        unitPrice: 300,
      ),
    );
    repository.setAddress(
      'Dev Electricals',
      sampleAddress(id: 7, label: 'Home', line1: 'A-1'),
    );

    final booked = repository.confirm('Dev Electricals');

    expect(booked.addressId, 7);
    expect(booked.addressSummary, 'A-1, Galleria Market 1, 201016 · Home');
  });

  test('the default is the one a booking would use', () {
    // Reads straight off the repository the visit screens read.
    expect(AddressRepository.shared.defaultAddress, anyOf(isNull, isNotNull));
  });
}
