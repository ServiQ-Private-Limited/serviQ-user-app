import 'package:local_markerplace/visit/repository/visit_repository.dart';
import 'package:local_markerplace/chat/repository/chat_repository.dart';
import 'package:local_markerplace/me/model/kyc_document.dart';
import 'package:local_markerplace/me/repository/address_repository.dart';
import 'package:local_markerplace/me/model/saved_provider.dart';
import 'package:local_markerplace/me/model/seeker_account.dart';
import 'package:local_markerplace/onboarding/model/seeker_profile.dart';

/// What the Me screens read.
///
/// The seeker's name and area come from the profile onboarding saved, so the
/// screen shows who is actually signed in; everything else is the seed data
/// drawn in the design, waiting on endpoints that do not exist yet.
class MeRepository {
  const MeRepository();

  /// The interest ids onboarding stores, spelled the way Edit profile shows
  /// them.
  static List<String> _interestLabels(Set<String> ids) => seekerServiceInterests
      .where((interest) => ids.contains(interest.id))
      .map((interest) => interest.label)
      .toList();

  /// Builds the account from [profile] where it can, and falls back to the
  /// design's figures for the counts no endpoint reports yet.
  SeekerAccount account({SeekerProfile? profile, String? phone}) {
    final interests = profile == null
        ? const <String>[]
        : _interestLabels(profile.interestIds);

    return SeekerAccount(
      name: profile?.fullName.isNotEmpty == true
          ? profile!.fullName
          : 'Your profile',
      phone: phone ?? '+91 98765 43210',
      localityName: profile?.locality.isNotEmpty == true
          ? profile!.locality
          : 'No area chosen',
      joined: 'joined Aug 2026',
      // Real session state, not a figure typed in: the row would otherwise
      // promise bookings the seeker does not have.
      bookedOrders: VisitRepository.shared.booked.length,
      unreadChats: ChatRepository.shared.unreadCount,
      savedProviderCount: savedProviders().length,
      // What the addresses endpoint last reported, not a figure typed in:
      // the row would otherwise promise addresses the seeker has not saved.
      // Null until something has been loaded, which the row reads as "not
      // counted yet" rather than as none.
      savedAddressCount: AddressRepository.shared.count,
      interests: interests.isEmpty
          ? const ['Home repairs', 'Cleaning']
          : interests,
      kycStatus: _rollUp(documents()),
    );
  }

  /// The account's own state is the best of what it has submitted: an
  /// approved document verifies the member even if a later one was rejected.
  static KycStatus _rollUp(List<KycDocument> documents) {
    if (documents.any((doc) => doc.status == KycStatus.approved)) {
      return KycStatus.approved;
    }
    if (documents.any((doc) => doc.status == KycStatus.underReview)) {
      return KycStatus.pending;
    }
    if (documents.any((doc) => doc.isRejected)) return KycStatus.rejected;
    return KycStatus.pending;
  }

  List<KycDocument> documents() => const [
    KycDocument(
      type: 'Aadhaar',
      status: KycStatus.approved,
      statusLine: 'Verified 12 Aug 2026',
    ),
    KycDocument(
      type: 'PAN',
      status: KycStatus.underReview,
      statusLine: 'Submitted 2 days ago',
    ),
    KycDocument(
      type: 'Driving Licence',
      status: KycStatus.rejected,
      statusLine: 'Rejected 1 day ago',
      rejectionReason:
          'Photo is blurry — please retake it in good light with all four '
          'corners visible.',
    ),
  ];

  /// The document types a seeker can submit.
  List<String> documentTypes() => const [
    'Aadhaar',
    'PAN',
    'Driving Licence',
    'Passport',
    'Voter ID',
  ];

  List<SavedProvider> savedProviders() => const [
    SavedProvider(
      name: 'Shahnaz RO & Chimney Services',
      trade: 'RO Repair',
      localityName: 'Ajnara Gen X',
      rating: 4.6,
      isOpen: true,
      usageNote: 'Used twice',
    ),
    SavedProvider(
      name: 'Sharma Carpentry',
      trade: 'Carpenter',
      localityName: 'Panchsheel Wellington',
      rating: 4.1,
      isOpen: true,
      usageNote: 'Used once',
    ),
    SavedProvider(
      name: 'CoolAir AC Service',
      trade: 'AC Repair',
      localityName: 'Ajnara Gen X',
      rating: 4.7,
      isOpen: true,
    ),
    SavedProvider(
      name: 'RK Electricals & Repairs',
      trade: 'Electrician',
      localityName: 'Ajnara Gen X',
      rating: 4.4,
      isOpen: false,
    ),
    SavedProvider(
      name: 'Galleria Home Services',
      trade: 'Cleaning',
      localityName: 'Galleria Market 1',
      rating: 4.3,
      isOpen: true,
    ),
    SavedProvider(
      name: 'Verma Plumbing Works',
      trade: 'Plumber',
      localityName: 'Ajnara Gen X',
      rating: 4.2,
      isOpen: true,
    ),
    SavedProvider(
      name: 'Mascot Appliance Care',
      trade: 'Appliance',
      localityName: 'Ajnara Gen X',
      rating: 4.0,
      isOpen: false,
    ),
  ];

}
