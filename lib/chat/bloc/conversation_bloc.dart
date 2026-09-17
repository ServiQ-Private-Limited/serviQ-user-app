import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import 'package:local_markerplace/chat/model/chat_message.dart';
import 'package:local_markerplace/chat/model/chat_thread.dart';
import 'package:local_markerplace/chat/repository/chat_repository.dart';
import 'package:local_markerplace/visit/model/visit.dart';
import 'package:local_markerplace/visit/model/visit_service.dart';
import 'package:local_markerplace/visit/repository/visit_repository.dart';

part 'conversation_event.dart';
part 'conversation_state.dart';

/// One conversation: what has been said, what the seeker sends, and what
/// happens to an offer inside it.
///
/// Taking an offer books the visit outright, the same way taking one on the
/// board does — the provider named a price and a time, and accepting agreed
/// to both — so the booking is this bloc's work rather than the screen's.
class ConversationBloc extends Bloc<ConversationEvent, ConversationState> {
  final ChatRepository chatRepository;
  final VisitRepository visitRepository;

  ConversationBloc({
    required this.chatRepository,
    required this.visitRepository,
  }) : super(const ConversationState.initial()) {
    on<ConversationOpened>(_onConversationOpened);
    on<MessageSent>(_onMessageSent);
    on<OfferAccepted>(_onOfferAccepted);
    on<OfferDeclined>(_onOfferDeclined);
    on<BookingSeen>(_onBookingSeen);
  }

  /// Opening a thread clears its badge — the seeker has now seen it.
  ///
  /// The thread is started here when there is none: chatting from a
  /// provider's page is the one way in that does not begin with a
  /// conversation already existing.
  void _onConversationOpened(
    ConversationOpened event,
    Emitter<ConversationState> emit,
  ) {
    chatRepository.openWith(
      event.providerName,
      isVerified: event.isVerified,
      replyLine: event.replyLine,
    );
    emit(
      state.copyWith(
        providerName: event.providerName,
        thread: chatRepository.markRead(event.providerName),
        isLoading: false,
      ),
    );
  }

  void _onMessageSent(MessageSent event, Emitter<ConversationState> emit) {
    final text = event.text.trim();
    if (text.isEmpty) return;
    emit(state.copyWith(thread: chatRepository.send(state.providerName, text)));
  }

  void _onOfferAccepted(OfferAccepted event, Emitter<ConversationState> emit) {
    final thread = chatRepository.answerOffer(
      state.providerName,
      event.messageIndex,
      ChatOfferStatus.accepted,
    );

    final booked = visitRepository.bookFromOffer(
      providerName: thread.providerName,
      providerLine: 'agreed in chat',
      isVerifiedProvider: thread.isVerified,
      agreedWhen: _capitalised(event.offer.timing),
      service: VisitService(
        name: thread.postTitle ?? 'Agreed in chat',
        detail: event.offer.terms,
        unitPrice: event.offer.price,
      ),
    );

    emit(state.copyWith(thread: thread, booked: booked));
  }

  void _onOfferDeclined(OfferDeclined event, Emitter<ConversationState> emit) {
    emit(
      state.copyWith(
        thread: chatRepository.answerOffer(
          state.providerName,
          event.messageIndex,
          ChatOfferStatus.declined,
        ),
      ),
    );
  }

  /// The screen has shown the receipt, so the booking is no longer news.
  /// Without this the same visit would be pushed again on the next rebuild.
  void _onBookingSeen(BookingSeen event, Emitter<ConversationState> emit) {
    emit(state.copyWith(booked: null));
  }

  static String _capitalised(String text) =>
      text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}
