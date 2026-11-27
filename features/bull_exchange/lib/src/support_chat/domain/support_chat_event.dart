import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

@immutable
sealed class SupportChatEvent {
  const SupportChatEvent();
}

/// The answer for the page a fetch with [ticket] asked for.
final class ChatPageLoaded extends SupportChatEvent {
  final int ticket;
  final Result<List<SupportChatMessage>, ExchangeFailure> result;

  const ChatPageLoaded(this.ticket, this.result);
}

final class ChatRetryPressed extends SupportChatEvent {
  const ChatRetryPressed();
}

/// The exchange pushed a chat notification.
final class ChatPushed extends SupportChatEvent {
  const ChatPushed();
}

final class ChatOlderRequested extends SupportChatEvent {
  const ChatOlderRequested();
}

final class ChatDraftChanged extends SupportChatEvent {
  final String text;

  const ChatDraftChanged(this.text);
}

final class ChatAttachPressed extends SupportChatEvent {
  const ChatAttachPressed();
}

final class ChatAttachmentsPicked extends SupportChatEvent {
  final Result<List<SupportChatMessageAttachment>, ExchangeFailure> result;

  const ChatAttachmentsPicked(this.result);
}

/// [line] is the localized sentence added to the draft with the logs.
final class ChatLogsPressed extends SupportChatEvent {
  final String line;

  const ChatLogsPressed(this.line);
}

final class ChatLogsBuilt extends SupportChatEvent {
  final Result<SupportChatMessageAttachment, ExchangeFailure> result;

  const ChatLogsBuilt(this.result);
}

final class ChatAttachmentRemoved extends SupportChatEvent {
  final SupportChatMessageAttachment attachment;

  const ChatAttachmentRemoved(this.attachment);
}

final class ChatSendPressed extends SupportChatEvent {
  const ChatSendPressed();
}

final class ChatSendAnswered extends SupportChatEvent {
  final String localId;
  final Result<void, ExchangeFailure> result;

  const ChatSendAnswered(this.localId, this.result);
}

final class ChatOpenPressed extends SupportChatEvent {
  final String attachmentId;

  const ChatOpenPressed(this.attachmentId);
}

final class ChatOpenFinished extends SupportChatEvent {
  final String attachmentId;
  final Result<void, ExchangeFailure> result;

  const ChatOpenFinished(this.attachmentId, this.result);
}
