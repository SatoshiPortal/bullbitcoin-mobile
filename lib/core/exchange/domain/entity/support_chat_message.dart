import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

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
