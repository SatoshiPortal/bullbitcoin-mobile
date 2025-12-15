import 'dart:typed_data';

import 'package:bb_mobile/core/exchange/data/models/support_chat_message_attachment_model.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'support_chat_message_model.freezed.dart';

@freezed
sealed class SupportChatMessageModel with _$SupportChatMessageModel {
  const factory SupportChatMessageModel({
    String? messageId,
    String? text,
    String? fromUserId,
    String? toGroupCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isAdmin,
    List<SupportChatMessageAttachmentModel>? attachments,
  }) = _SupportChatMessageModel;

  factory SupportChatMessageModel.fromJsonWithUserId(
    Map<String, dynamic> json,
    String userId,
  ) {
    final fromUserId = json['fromUserId'] as String?;
    final isAdmin = fromUserId != userId;

    return SupportChatMessageModel(
      messageId: json['messageId'] as String?,
      text: json['text'] as String?,
      fromUserId: fromUserId,
      toGroupCode: json['toGroupCode'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      isAdmin: isAdmin,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.where((attachmentJson) => attachmentJson != null)
          .map((attachmentJson) {
            final attachment = attachmentJson as Map<String, dynamic>;
            Uint8List? fileDataBytes;

            if (attachment['fileData'] != null) {
              if (attachment['fileData'] is Map<String, dynamic> &&
                  attachment['fileData']['data'] != null) {
                fileDataBytes = Uint8List.fromList(
                  List<int>.from(attachment['fileData']['data'] as List),
                );
              } else if (attachment['fileData'] is List) {
                fileDataBytes = Uint8List.fromList(
                  List<int>.from(attachment['fileData'] as List),
                );
              }
            }

            return SupportChatMessageAttachmentModel(
              attachmentId: attachment['attachmentId'] as String?,
              fileName: attachment['fileName'] as String?,
              fileType: attachment['fileType'] as String?,
              fileSize: attachment['fileSize'] as int?,
              fileData: fileDataBytes,
              messageId:
                  attachment['messageId'] as String? ??
                  json['messageId'] as String?,
              createdAt: attachment['createdAt'] != null
                  ? DateTime.tryParse(attachment['createdAt'] as String)
                  : null,
            );
          })
          .where((att) => att.attachmentId != null || att.fileName != null)
          .toList(),
    );
  }

  const SupportChatMessageModel._();

  SupportChatMessage toEntity() {
    return SupportChatMessage(
      messageId: messageId,
      text: text,
      fromUserId: fromUserId,
      toGroupCode: toGroupCode,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isAdmin: isAdmin,
      attachments: attachments?.map((a) => a.toEntity()).toList(),
    );
  }
}
