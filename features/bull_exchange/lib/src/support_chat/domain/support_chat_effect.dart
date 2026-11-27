import 'package:exchange/exchange.dart';
import 'package:meta/meta.dart';

import 'support_chat_state.dart';

@immutable
sealed class SupportChatEffect {
  const SupportChatEffect();
}

final class ChatFetchPage extends SupportChatEffect {
  final int ticket;
  final int page;

  const ChatFetchPage(this.ticket, this.page);

  @override
  bool operator ==(Object other) =>
      other is ChatFetchPage && other.ticket == ticket && other.page == page;

  @override
  int get hashCode => Object.hash(ChatFetchPage, ticket, page);
}

/// The newest page is on screen: the user has seen every message.
final class ChatNewestShown extends SupportChatEffect {
  const ChatNewestShown();

  @override
  bool operator ==(Object other) => other is ChatNewestShown;

  @override
  int get hashCode => (ChatNewestShown).hashCode;
}

final class ChatPickImages extends SupportChatEffect {
  const ChatPickImages();

  @override
  bool operator ==(Object other) => other is ChatPickImages;

  @override
  int get hashCode => (ChatPickImages).hashCode;
}

final class ChatBuildLogs extends SupportChatEffect {
  const ChatBuildLogs();

  @override
  bool operator ==(Object other) => other is ChatBuildLogs;

  @override
  int get hashCode => (ChatBuildLogs).hashCode;
}

final class ChatSend extends SupportChatEffect {
  final String localId;
  final String text;
  final List<SupportChatMessageAttachment> attachments;

  const ChatSend(this.localId, this.text, this.attachments);

  @override
  bool operator ==(Object other) =>
      other is ChatSend &&
      other.localId == localId &&
      other.text == text &&
      chatListEquals(other.attachments, attachments);

  @override
  int get hashCode =>
      Object.hash(ChatSend, localId, text, Object.hashAll(attachments));
}

final class ChatOpenAttachment extends SupportChatEffect {
  final String attachmentId;

  const ChatOpenAttachment(this.attachmentId);

  @override
  bool operator ==(Object other) =>
      other is ChatOpenAttachment && other.attachmentId == attachmentId;

  @override
  int get hashCode => Object.hash(ChatOpenAttachment, attachmentId);
}
