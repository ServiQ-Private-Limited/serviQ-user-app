import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:local_markerplace/chat/bloc/conversation_bloc.dart';
import 'package:local_markerplace/chat/model/chat_message.dart';
import 'package:local_markerplace/chat/model/chat_thread.dart';
import 'package:local_markerplace/chat/presentation/components/chat_bits.dart';
import 'package:local_markerplace/chat/repository/chat_repository.dart';
import 'package:local_markerplace/components/app_back_button.dart';
import 'package:local_markerplace/core/app_color.dart';
import 'package:local_markerplace/discovery/presentation/components/discovery_text.dart';
import 'package:local_markerplace/discovery/presentation/components/provider_avatar.dart';
import 'package:local_markerplace/visit/model/visit.dart';
import 'package:local_markerplace/visit/presentation/visit_booked_page.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

/// One conversation.
///
/// Everything the two of them agreed is here, including the price: an offer
/// is a message, so accepting one is answering the person rather than
/// leaving for a form.
class ConversationPage extends StatelessWidget {
  const ConversationPage({
    super.key,
    required this.providerName,
    this.isVerified = true,
    this.replyLine,
    this.repository,
    this.visits,
  });

  final String providerName;

  /// Only used when there is no thread yet and this open starts one.
  final bool isVerified;
  final String? replyLine;
  final ChatRepository? repository;
  final VisitRepository? visits;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ConversationBloc(
        chatRepository: repository ?? ChatRepository.shared,
        visitRepository: visits ?? VisitRepository.shared,
      )..add(
        ConversationOpened(
          providerName,
          isVerified: isVerified,
          replyLine: replyLine,
        ),
      ),
      child: const _ConversationView(),
    );
  }
}

class _ConversationView extends StatefulWidget {
  const _ConversationView();

  @override
  State<_ConversationView> createState() => _ConversationViewState();
}

class _ConversationViewState extends State<_ConversationView> {
  /// Both belong to the widget: one holds what is being typed, the other
  /// where the list is scrolled to. Neither is state the bloc should carry.
  final TextEditingController _message = TextEditingController();
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // Opening a thread should land on the newest message, not the oldest.
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  @override
  void dispose() {
    _message.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Opening the keyboard shortens the list; without this the message the
    // seeker is replying to slides out of sight behind it.
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    if (inset > 0 && inset != _lastInset) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
    }
    _lastInset = inset;
  }

  double _lastInset = 0;

  void _send() {
    final text = _message.text.trim();
    if (text.isEmpty) return;
    context.read<ConversationBloc>().add(MessageSent(text));
    _message.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  /// Accepting books the visit, so the receipt follows it. The bloc says a
  /// booking happened; showing it is the screen's job, and telling the bloc
  /// it has been shown is what stops it being shown twice.
  Future<void> _showReceipt(Visit booked) async {
    final bloc = context.read<ConversationBloc>();
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => VisitBookedPage(visit: booked)));
    bloc.add(const BookingSeen());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ConversationBloc>().state;
    final thread = state.thread;
    if (thread == null) {
      return const Scaffold(backgroundColor: AppColor.white);
    }
    final messages = state.messages;

    return Scaffold(
      backgroundColor: AppColor.white,
      body: BlocListener<ConversationBloc, ConversationState>(
        listenWhen: (previous, current) =>
            previous.booked != current.booked && current.booked != null,
        listener: (context, state) => _showReceipt(state.booked!),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _Header(thread: thread),
              const Divider(
                height: 1,
                thickness: 1,
                color: AppColor.discoveryBorder,
              ),
              Expanded(
                child: messages.isEmpty
                    ? _NothingSaidYet(providerName: thread.providerName)
                    : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    // The last row is the note about what accepting does; it
                    // belongs with the conversation rather than pinned, so it
                    // scrolls away once the thread grows.
                    if (index == messages.length) {
                      return _AcceptNote(thread: thread);
                    }

                    final message = messages[index];
                    final previous = index == 0 ? null : messages[index - 1];
                    final offer = message.offer;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_startsNewDay(previous, message))
                          ChatDayLabel(label: _dayLabel(message.sentAt)),
                        if (message.text.isNotEmpty)
                          MessageBubble(message: message),
                        if (offer != null)
                          ChatOfferCard(
                            offer: offer,
                            timeLabel: message.timeLabel,
                            onAccept: () =>
                                context.read<ConversationBloc>().add(
                                  OfferAccepted(
                                    messageIndex: index,
                                    offer: offer,
                                  ),
                                ),
                            onDecline: () => context
                                .read<ConversationBloc>()
                                .add(OfferDeclined(index)),
                          ),
                      ],
                    );
                  },
                ),
              ),
              // The composer sits inside the body, not in the Scaffold's
              // bottomNavigationBar: that keeps its place under the keyboard,
              // which hid the field and the send button behind it.
              ChatComposer(controller: _message, canSend: true, onSend: _send),
            ],
          ),
        ),
      ),
    );
  }

  static bool _startsNewDay(ChatMessage? previous, ChatMessage message) {
    if (previous == null) return true;
    final a = previous.sentAt;
    final b = message.sentAt;
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  static String _dayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(
      date.year,
      date.month,
      date.day,
    ).difference(today).inDays;
    if (days == 0) return 'Today';
    if (days == -1) return 'Yesterday';
    const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return names[date.weekday - 1];
  }
}

/// Who the conversation is with, and what it is about.
class _Header extends StatelessWidget {
  const _Header({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    final about = thread.postTitle;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 20, 10),
      child: Row(
        children: [
          const AppBackButton(),
          const SizedBox(width: 6),
          ProviderAvatar(
            initials: thread.initials,
            seed: thread.providerName,
            size: 40,
            isVerified: thread.isVerified,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  thread.providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: DiscoveryText.rowTitle.copyWith(fontSize: 14.5),
                ),
                if (about != null || thread.replyLine.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    about == null ? thread.replyLine : 'On "$about"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DiscoveryText.smallPrint,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What accepting an offer costs the seeker in privacy, said where the
/// offer is.
class _AcceptNote extends StatelessWidget {
  const _AcceptNote({required this.thread});

  final ChatThread thread;

  @override
  Widget build(BuildContext context) {
    if (!thread.hasPendingOffer) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Text(
        'Accepting shares your number with ${thread.providerName} only.',
        textAlign: TextAlign.center,
        style: DiscoveryText.fine,
      ),
    );
  }
}

/// A conversation that has just been started from a provider's page.
///
/// Says so rather than opening on a blank scroll: nobody has written
/// anything, and a thread with no messages is a normal thing to be looking
/// at when you are the one about to send the first.
class _NothingSaidYet extends StatelessWidget {
  const _NothingSaidYet({required this.providerName});

  final String providerName;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 34,
              color: AppColor.discoveryTextTertiary,
            ),
            const SizedBox(height: 14),
            Text(
              'No messages yet',
              textAlign: TextAlign.center,
              style: DiscoveryText.sectionTitleSmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Say what you need and $providerName will pick it up here. '
              'Your number stays hidden until you accept an offer.',
              textAlign: TextAlign.center,
              style: DiscoveryText.publicNote,
            ),
          ],
        ),
      ),
    );
  }
}
