import 'package:freezed_annotation/freezed_annotation.dart';

import 'support_chat_message_attachment.dart';

part 'support_chat_message.freezed.dart';

@freezed
sealed class SupportChatMessage with _$SupportChatMessage {
  const factory SupportChatMessage({
    String? messageId,
    String? text,
    String? fromUserId,
    String? toGroupCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAdmin,
    List<SupportChatMessageAttachment>? attachments,
  }) = _SupportChatMessage;
}
