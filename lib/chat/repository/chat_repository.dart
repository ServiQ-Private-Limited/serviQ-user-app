import 'dart:async';

import 'package:local_markerplace/chat/model/chat_message.dart';
import 'package:local_markerplace/chat/model/chat_thread.dart';

/// The seeker's conversations.
///
/// There is no messaging endpoint yet, so this holds the session's threads —
/// seeded with the ones the design draws, and mutable so a message sent on
/// the device stays sent while the app is open.
class ChatRepository {
  ChatRepository({List<ChatThread>? threads}) : _threads = threads ?? _seeded();

  static final ChatRepository shared = ChatRepository();

  /// Announced whenever a thread changes.
  ///
  /// Home badges the unread count, and reading a thread happens on a screen
  /// home cannot see — so it is told rather than left to notice.
  Stream<void> get changes => _changes.stream;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  void _announce() {
    if (!_changes.isClosed) _changes.add(null);
  }

  final List<ChatThread> _threads;

  /// Newest conversation first, which is the order the list reads in.
  List<ChatThread> get threads => List.unmodifiable(_threads);

  int get unreadCount =>
      _threads.fold(0, (sum, thread) => sum + thread.unreadCount);

  /// Threads whose provider or last message matches [query]. An empty query
  /// is everything.
  List<ChatThread> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return threads;
    return _threads
        .where(
          (thread) =>
              thread.providerName.toLowerCase().contains(needle) ||
              thread.previewLine.toLowerCase().contains(needle),
        )
        .toList();
  }

  ChatThread byName(String providerName) =>
      _threads.firstWhere((thread) => thread.providerName == providerName);

  /// The thread with [providerName], whether or not there was one.
  ///
  /// Chatting from a provider's page has to land somewhere: if they have
  /// spoken before it is that conversation, and if they have not it is a new
  /// empty one rather than a crash. [byName] throws for a provider with no
  /// thread, which is right for a list that only shows threads that exist
  /// and wrong for a button that starts one.
  ///
  /// A started thread carries no messages, because none have been sent. The
  /// conversation screen says so rather than opening with something nobody
  /// wrote.
  ChatThread openWith(
    String providerName, {
    bool isVerified = true,
    String? replyLine,
  }) {
    final existing = _indexOf(providerName);
    if (existing != -1) return _threads[existing];

    final started = ChatThread(
      providerName: providerName,
      messages: const [],
      isVerified: isVerified,
      // Only when the provider's own page said so. The default is a line
      // nobody measured, so a thread started without one leaves it out.
      replyLine: replyLine ?? '',
    );
    _threads.insert(0, started);
    _announce();
    return started;
  }

  /// Whether a conversation with them has been started.
  bool hasThreadWith(String providerName) => _indexOf(providerName) != -1;

  int _indexOf(String providerName) =>
      _threads.indexWhere((thread) => thread.providerName == providerName);

  /// Opening a thread clears its badge — the seeker has now seen it.
  ChatThread markRead(String providerName) {
    final index = _indexOf(providerName);
    if (index == -1) return byName(providerName);
    final read = _threads[index] = _threads[index].copyWith(unreadCount: 0);
    _announce();
    return read;
  }

  /// Sends a message from the seeker and moves the thread to the top.
  ChatThread send(String providerName, String text) {
    final index = _indexOf(providerName);
    final thread = _threads[index];
    final updated = thread.copyWith(
      messages: [
        ...thread.messages,
        ChatMessage(text: text, sentAt: DateTime.now(), isMine: true),
      ],
      unreadCount: 0,
    );
    _threads
      ..removeAt(index)
      ..insert(0, updated);
    _announce();
    return updated;
  }

  /// Answers the offer carried by the message at [messageIndex].
  ///
  /// The offer stays in the thread either way — a declined price is part of
  /// the conversation that followed it, and hiding it would make the next
  /// message read as a non sequitur.
  ChatThread answerOffer(
    String providerName,
    int messageIndex,
    ChatOfferStatus status,
  ) {
    final index = _indexOf(providerName);
    final thread = _threads[index];
    final messages = [...thread.messages];
    final message = messages[messageIndex];
    final offer = message.offer;
    if (offer == null) return thread;
    messages[messageIndex] = message.copyWith(
      offer: offer.copyWith(status: status),
    );
    final answered = _threads[index] = thread.copyWith(messages: messages);
    _announce();
    return answered;
  }

  /// The conversations the design draws, aged off the current clock so the
  /// list always reads "2 min" and "yesterday" rather than a fixed date.
  static List<ChatThread> _seeded() {
    final now = DateTime.now();
    DateTime ago(Duration elapsed) => now.subtract(elapsed);

    return [
      ChatThread(
        providerName: 'Shahnaz RO & Chimney',
        unreadCount: 2,
        messages: [
          ChatMessage(
            text:
                'Hi, my AC in the bedroom is not cooling and the outdoor '
                'unit rattles.',
            sentAt: ago(const Duration(hours: 3, minutes: 7)),
            isMine: true,
          ),
          ChatMessage(
            text: 'I can look at it today. Is 4 to 6 pm alright?',
            sentAt: ago(const Duration(hours: 3, minutes: 4)),
            isMine: false,
          ),
          ChatMessage(
            text: 'Yes that works. Both units need a service.',
            sentAt: ago(const Duration(hours: 3, minutes: 2)),
            isMine: true,
          ),
          ChatMessage(
            text: 'Booked. ₹899 for two units, gas top-up extra if needed.',
            sentAt: ago(const Duration(hours: 3)),
            isMine: false,
          ),
          ChatMessage(
            text: 'I can come at 4 instead, does that work?',
            sentAt: ago(const Duration(minutes: 2)),
            isMine: false,
          ),
        ],
      ),
      ChatThread(
        providerName: 'Sharma Carpentry',
        messages: [
          ChatMessage(
            text: 'Wardrobe hinge is loose, can you look at it?',
            sentAt: ago(const Duration(hours: 2)),
            isMine: true,
          ),
          ChatMessage(
            text: 'Yes, tomorrow morning suits me.',
            sentAt: ago(const Duration(hours: 1, minutes: 20)),
            isMine: false,
          ),
          ChatMessage(
            text: 'Great, see you tomorrow',
            sentAt: ago(const Duration(hours: 1)),
            isMine: true,
          ),
        ],
      ),
      ChatThread(
        providerName: 'CoolAir AC Service',
        postTitle: 'AC not cooling, makes noise',
        replyLine: 'Usually replies in 20 min',
        messages: [
          ChatMessage(
            text: 'Hello, I saw your post. I can do both units.',
            sentAt: ago(const Duration(days: 1, hours: 2)),
            isMine: false,
          ),
          ChatMessage(
            text: '',
            sentAt: ago(const Duration(days: 1, hours: 2)),
            isMine: false,
            offer: const ChatOffer(
              price: 1100,
              terms: 'Tomorrow morning · 30-day warranty',
            ),
          ),
          ChatMessage(
            text: 'Can you do ₹950? I have two units.',
            sentAt: ago(const Duration(days: 1, hours: 1)),
            isMine: true,
          ),
        ],
      ),
      ChatThread(
        providerName: 'Imran AC Works',
        isVerified: false,
        replyLine: 'Usually replies in an hour',
        messages: [
          ChatMessage(
            text: 'Gas refill is ₹1,800 including pressure test.',
            sentAt: ago(const Duration(days: 3, hours: 1)),
            isMine: false,
          ),
          ChatMessage(
            text: 'Thanks, will let you know',
            sentAt: ago(const Duration(days: 3)),
            isMine: true,
          ),
        ],
      ),
    ];
  }
}
