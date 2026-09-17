part of 'conversation_bloc.dart';

sealed class ConversationEvent extends Equatable {
  const ConversationEvent();
}

/// Read the thread and clear its badge.
final class ConversationOpened extends ConversationEvent {
  final String providerName;

  /// What the provider's own page knows about them, used only when there is
  /// no thread yet and one has to be started.
  final bool isVerified;
  final String? replyLine;

  const ConversationOpened(
    this.providerName, {
    this.isVerified = true,
    this.replyLine,
  });

  @override
  List<Object?> get props => [providerName, isVerified, replyLine];
}

final class MessageSent extends ConversationEvent {
  final String text;

  const MessageSent(this.text);

  @override
  List<Object> get props => [text];
}

/// Takes the offer at [messageIndex] and books the visit it describes.
final class OfferAccepted extends ConversationEvent {
  final int messageIndex;
  final ChatOffer offer;

  const OfferAccepted({required this.messageIndex, required this.offer});

  @override
  List<Object> get props => [messageIndex, offer];
}

final class OfferDeclined extends ConversationEvent {
  final int messageIndex;

  const OfferDeclined(this.messageIndex);

  @override
  List<Object> get props => [messageIndex];
}

/// The receipt for the booking has been shown.
final class BookingSeen extends ConversationEvent {
  const BookingSeen();

  @override
  List<Object> get props => [];
}
