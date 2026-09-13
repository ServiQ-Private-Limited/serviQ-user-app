import 'package:equatable/equatable.dart';

/// What a notification is about, which is all the row needs to pick its mark.
///
/// This is the *look*, not the server's taxonomy: the backend names events
/// ("VISIT_CONFIRMED", "DISPATCH_NO_PARTNER") and there will be more of them
/// than the drawer has marks, so [notificationKindFrom] maps many onto these
/// few rather than the drawer growing a case per event.
enum NotificationKind {
  /// A provider has offered on one of the seeker's requirements.
  offer,

  /// Something the seeker was waiting on came good — a visit confirmed, an
  /// offer accepted, a document approved.
  accepted,

  /// Something did not come good: nobody took the job, a visit fell through.
  problem,

  /// A direct message.
  message,

  /// News about the seeker's area rather than about them.
  area,
}

/// Reads the server's event name into one of the drawer's marks.
///
/// Unknown events are shown rather than dropped — a notification nobody can
/// see is worse than one wearing the neutral mark, and the backend will add
/// events faster than this app learns them.
NotificationKind notificationKindFrom(String kind) {
  final name = kind.toUpperCase();
  if (name.contains('OFFER') && !name.contains('ACCEPTED')) {
    return NotificationKind.offer;
  }
  if (name.contains('MESSAGE') || name.contains('CHAT')) {
    return NotificationKind.message;
  }
  if (name.contains('NO_PARTNER') ||
      name.contains('FAILED') ||
      name.contains('CANCELLED') ||
      name.contains('REJECTED') ||
      name.contains('EXPIRED')) {
    return NotificationKind.problem;
  }
  if (name.contains('CONFIRMED') ||
      name.contains('ACCEPTED') ||
      name.contains('APPROVED') ||
      name.contains('COMPLETED')) {
    return NotificationKind.accepted;
  }
  return NotificationKind.area;
}

/// One line in the notifications drawer.
class AppNotification extends Equatable {
  const AppNotification({
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.id,
    this.eventName = '',
    this.entityType,
    this.entityCode,
    this.isUnread = false,
  });

  /// The server's id. Null for anything built locally.
  final int? id;

  final NotificationKind kind;

  /// The server's own event name, kept so a row can be acted on later even
  /// though the mark has already collapsed it into a kind.
  final String eventName;

  /// "VISIT" — what [entityCode] refers to.
  final String? entityType;

  /// "VISFDSY04M5" — the thing the notification is about, which is what a tap
  /// will eventually open.
  final String? entityCode;

  /// "Shahnaz RO & Chimney offered ₹899" — wraps to two lines where it has to.
  final String title;

  /// The line under it, naming what the notification is about.
  final String body;

  /// When it arrived. The drawer groups and stamps from this rather than
  /// storing a pre-formatted string, so "20 min" stays true while the sheet
  /// is open.
  final DateTime at;

  final bool isUnread;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final eventName = json['kind'] as String? ?? '';

    return AppNotification(
      id: json['id'] as int?,
      kind: notificationKindFrom(eventName),
      eventName: eventName,
      entityType: json['entityType'] as String?,
      entityCode: json['entityCode'] as String?,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      at: _parseCreatedAt(json['createdAt'] as String? ?? ''),
      // "read" is the server's word for it; the drawer thinks in unread.
      isUnread: !(json['read'] as bool? ?? false),
    );
  }

  /// Reads the server's timestamp, which is UTC written without the Z.
  ///
  /// `responseTime` carries its zone but `createdAt` does not, so taking the
  /// stamp at face value reads it as local time and lands it a whole offset
  /// in the past — a notification three minutes old was stamped "5 h" on a
  /// device in IST. Anything that does name a zone is trusted as it is.
  static DateTime _parseCreatedAt(String raw) {
    if (raw.isEmpty) return DateTime.now();
    final namesAZone =
        raw.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(raw);
    final parsed = DateTime.tryParse(namesAZone ? raw : '${raw}Z');
    // Local, because the drawer groups TODAY against the device's own day.
    return parsed?.toLocal() ?? DateTime.now();
  }

  /// Whether this belongs under TODAY rather than EARLIER.
  bool isToday(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return !at.isBefore(today);
  }

  /// "20 min" / "2 h" / "4 d", as the design stamps each row.
  ///
  /// Past a day the count is of calendar days, not of elapsed 24-hour
  /// blocks. Two notifications half an hour apart were otherwise stamped
  /// "3 d" and "4 d" — both arrived on the same afternoon, and only one of
  /// them had happened to cross the boundary by the time they were read.
  String get age {
    final now = DateTime.now();
    final difference = now.difference(at);
    if (difference.inMinutes < 1) return 'now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min';
    if (difference.inHours < 24) return '${difference.inHours} h';

    final days = DateTime(now.year, now.month, now.day)
        .difference(DateTime(at.year, at.month, at.day))
        .inDays;
    // A day's worth of hours has already passed by the time we are here, so
    // a zone that shortened the day cannot make this read "0 d".
    return '${days < 1 ? 1 : days} d';
  }

  AppNotification copyWith({bool? isUnread}) => AppNotification(
    id: id,
    kind: kind,
    eventName: eventName,
    entityType: entityType,
    entityCode: entityCode,
    title: title,
    body: body,
    at: at,
    isUnread: isUnread ?? this.isUnread,
  );

  @override
  List<Object?> get props => [
    id,
    kind,
    eventName,
    entityType,
    entityCode,
    title,
    body,
    at,
    isUnread,
  ];
}

/// One page of the drawer, as the endpoint returns it.
class NotificationPage extends Equatable {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.size,
    required this.totalItems,
    required this.totalPages,
    required this.hasNext,
  });

  final List<AppNotification> items;
  final int page;
  final int size;
  final int totalItems;
  final int totalPages;

  /// Whether another page follows this one — what the drawer loads on.
  final bool hasNext;

  const NotificationPage.empty()
    : items = const [],
      page = 0,
      size = 0,
      totalItems = 0,
      totalPages = 0,
      hasNext = false;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    return NotificationPage(
      items: [
        if (json['items'] is List)
          for (final entry in json['items'] as List)
            if (entry is Map)
              AppNotification.fromJson(Map<String, dynamic>.from(entry)),
      ],
      page: json['page'] as int? ?? 0,
      size: json['size'] as int? ?? 0,
      totalItems: json['totalItems'] as int? ?? 0,
      totalPages: json['totalPages'] as int? ?? 0,
      hasNext: json['hasNext'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    items,
    page,
    size,
    totalItems,
    totalPages,
    hasNext,
  ];
}
