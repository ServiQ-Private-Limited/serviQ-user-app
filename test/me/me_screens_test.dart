import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/me/model/kyc_document.dart';
import 'package:local_markerplace/me/presentation/edit_profile_page.dart';
import 'package:local_markerplace/me/presentation/kyc_pages.dart';
import 'package:local_markerplace/me/presentation/me_page.dart';
import 'package:local_markerplace/me/presentation/saved_providers_page.dart';
import 'package:local_markerplace/me/repository/me_repository.dart';
import 'package:local_markerplace/onboarding/model/seeker_profile.dart';

Future<void> loadFonts() async {
  for (final path in const [
    'assets/fonts/Mulish-Medium.ttf',
    'assets/fonts/Mulish-Bold.ttf',
    'assets/fonts/Mulish-ExtraBold.ttf',
  ]) {
    final loader = FontLoader('Mulish')
      ..addFont(File(path).readAsBytes().then((b) => ByteData.view(b.buffer)));
    await loader.load();
  }
}

void main() {
  const repository = MeRepository();
  const profile = SeekerProfile(
    fullName: 'Priya Sharma',
    locality: 'Ajnara Gen X',
    interestIds: {'electrical', 'cleaning'},
  );
  final account = repository.account(profile: profile);

  setUpAll(loadFonts);

  Future<void> pump(WidgetTester tester, Widget screen, {Size? size}) async {
    final target = size ?? const Size(390, 844);
    tester.view.physicalSize = target * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: screen));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  Widget meScreen() => Scaffold(
    backgroundColor: AppColor.white,
    body: SafeArea(bottom: false, child: MeView(account: account)),
  );

  testWidgets('Me shows who is signed in and the way out', (tester) async {
    await pump(tester, meScreen());

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('Ajnara Gen X · joined Aug 2026'), findsOneWidget);
    expect(find.text('Identity verification'), findsOneWidget);
    // The gap that has been open since discovery replaced the dashboard.
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Sign out everywhere'), findsOneWidget);
  });

  testWidgets('the account rolls its documents up into one status', (
    tester,
  ) async {
    await pump(tester, meScreen());

    // Aadhaar is approved, so the account reads as verified even though a
    // later document was rejected.
    expect(find.text('APPROVED'), findsOneWidget);
  });

  testWidgets('Edit profile locks the phone and keeps the rest editable', (
    tester,
  ) async {
    await pump(tester, EditProfilePage(account: account));

    expect(find.text('Priya Sharma'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.textContaining('cannot be changed here'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('the KYC list shows every state with its reason', (tester) async {
    await pump(tester, const KycListPage());

    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('UNDER REVIEW'), findsOneWidget);
    expect(find.text('REJECTED'), findsOneWidget);
    // The reviewer's words, quoted rather than summarised.
    expect(find.textContaining('Photo is blurry'), findsOneWidget);
    expect(find.text('Re-upload'), findsOneWidget);
  });

  testWidgets('upload will not submit until both sides are in', (tester) async {
    await pump(tester, const KycUploadPage());

    expect(find.text('Add the back side to submit'), findsOneWidget);

    // Adding the back side turns the button into a real action.
    await tester.tap(find.text('Take a photo or choose a file'));
    await tester.pumpAndSettle();
    expect(find.text('Submit for review'), findsOneWidget);
  });

  testWidgets('a rejection repeats the reason word for word', (tester) async {
    final rejected = repository.documents().firstWhere((d) => d.isRejected);
    await pump(tester, KycRejectedPage(document: rejected));

    expect(find.text('Not accepted'), findsOneWidget);
    expect(find.textContaining(rejected.rejectionReason!), findsOneWidget);
    expect(find.text('Retake and re-upload'), findsOneWidget);
  });

  testWidgets('saved providers can be narrowed to the seeker\'s own area', (
    tester,
  ) async {
    await pump(tester, const SavedProvidersPage(localityName: 'Ajnara Gen X'));

    final all = repository.savedProviders();
    final nearMe = all
        .where((provider) => provider.localityName == 'Ajnara Gen X')
        .toList();

    expect(find.text('All ${all.length}'), findsOneWidget);
    expect(find.text('Sharma Carpentry'), findsOneWidget);

    await tester.tap(find.text('Near me ${nearMe.length}'));
    await tester.pumpAndSettle();
    // Panchsheel Wellington is not the seeker's area.
    expect(find.text('Sharma Carpentry'), findsNothing);
  });


  for (final size in const [Size(320, 568), Size(360, 640), Size(428, 926)]) {
    final label = '${size.width.toInt()}x${size.height.toInt()}';

    testWidgets('Me fits $label', (tester) async {
      await pump(tester, meScreen(), size: size);
    });

    testWidgets('the KYC screens fit $label', (tester) async {
      await pump(tester, const KycListPage(), size: size);
      await pump(tester, const KycUploadPage(), size: size);
    });

    testWidgets('Edit profile fits $label', (tester) async {
      await pump(tester, EditProfilePage(account: account), size: size);
    });
  }

  test(
    'an approved document verifies the account despite a later rejection',
    () {
      expect(account.kycStatus, KycStatus.approved);
    },
  );

  test('the account reads its name and area from the stored profile', () {
    expect(account.name, 'Priya Sharma');
    expect(account.localityName, 'Ajnara Gen X');
    expect(account.interests, containsAll(['Electrical', 'Cleaning']));
  });

  test('a seeker with no profile still gets a usable account', () {
    final blank = repository.account();

    expect(blank.name, 'Your profile');
    expect(blank.localityName, 'No area chosen');
    expect(blank.interests, isNotEmpty);
  });

  test('counts on Me match the lists behind them', () {
    expect(account.savedProviderCount, repository.savedProviders().length);
  });

  test('the address count stays absent until the endpoint has answered', () {
    // Zero saved and not yet counted are different things, and the row must
    // not claim the first when it means the second.
    expect(account.savedAddressCount, isNull);
  });
}
