import 'dart:typed_data';

import 'package:meta/meta.dart';

/// A support chat message from `listMessages`.
@immutable
class SupportMessage {
  final String? messageId;
  final String? text;
  final String? fromUserId;
  final String? toGroupCode;

  /// `null` when missing or not a date.
  final DateTime? createdAt;

  /// `null` when missing or not a date.
  final DateTime? updatedAt;

  /// `null` when the server omits the list; `null` elements are skipped.
  final List<SupportAttachment>? attachments;

  const SupportMessage({
    this.messageId,
    this.text,
    this.fromUserId,
    this.toGroupCode,
    this.createdAt,
    this.updatedAt,
    this.attachments,
  });
}

/// A support chat attachment.
@immutable
class SupportAttachment {
  final String? attachmentId;
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  final Uint8List? fileData;
  final String? messageId;

  /// `null` when missing or not a date.
  final DateTime? createdAt;

  const SupportAttachment({
    this.attachmentId,
    this.fileName,
    this.fileType,
    this.fileSize,
    this.fileData,
    this.messageId,
    this.createdAt,
  });
}

/// An attachment sent with `sendMessageToSupport`; [fileData] goes on the
/// wire as base64.
@immutable
class NewSupportAttachment {
  final String? fileName;
  final String? fileType;
  final int? fileSize;
  final List<int> fileData;

  const NewSupportAttachment({
    this.fileName,
    this.fileType,
    this.fileSize,
    required this.fileData,
  });
}
