import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_chat_message_attachment_model.freezed.dart';

@freezed
sealed class SupportChatMessageAttachmentModel
    with _$SupportChatMessageAttachmentModel {
  const factory SupportChatMessageAttachmentModel({
    String? attachmentId,
    String? fileName,
    String? fileType,
    int? fileSize,
    Uint8List? fileData,
    String? messageId,
    DateTime? createdAt,
  }) = _SupportChatMessageAttachmentModel;

  const SupportChatMessageAttachmentModel._();

  SupportChatMessageAttachment toEntity() {
    return SupportChatMessageAttachment(
      attachmentId: attachmentId,
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
      fileData: fileData,
      messageId: messageId,
      createdAt: createdAt,
    );
  }
}

