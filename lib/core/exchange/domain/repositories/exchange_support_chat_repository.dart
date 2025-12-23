import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';

abstract class ExchangeSupportChatRepository {
  Future<List<SupportChatMessage>> getMessages({int? page, int? pageSize});

  Future<void> sendMessage({
    required String text,
    List<SupportChatMessageAttachment>? attachments,
  });

  Future<SupportChatMessageAttachment> getMessageAttachment(
    String attachmentId,
  );
}
