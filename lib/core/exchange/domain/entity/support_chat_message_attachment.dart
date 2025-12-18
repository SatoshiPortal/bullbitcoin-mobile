import 'dart:typed_data';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_chat_message_attachment.freezed.dart';

@freezed
sealed class SupportChatMessageAttachment with _$SupportChatMessageAttachment {
  const factory SupportChatMessageAttachment({
    String? attachmentId,
    String? fileName,
    String? fileType,
    int? fileSize,
    Uint8List? fileData,
    String? messageId,
    DateTime? createdAt,
  }) = _SupportChatMessageAttachment;
}
