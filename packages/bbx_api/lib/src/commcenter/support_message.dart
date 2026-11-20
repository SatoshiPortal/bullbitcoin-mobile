import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/src/bbx_api_exception.dart';
import 'package:bbx_api/src/json.dart';
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

  /// Reads [SupportAttachment.fileData] only from a byte array: a base64
  /// string is `null` here.
  factory SupportMessage.fromJson(Map<String, dynamic> json) {
    final attachments = read<List<dynamic>?>(
      json['attachments'],
      'attachments',
    );
    return SupportMessage(
      messageId: read<String?>(json['messageId'], 'messageId'),
      text: read<String?>(json['text'], 'text'),
      fromUserId: read<String?>(json['fromUserId'], 'fromUserId'),
      toGroupCode: read<String?>(json['toGroupCode'], 'toGroupCode'),
      createdAt: _date(json['createdAt'], 'createdAt'),
      updatedAt: _date(json['updatedAt'], 'updatedAt'),
      attachments: attachments == null
          ? null
          : [
              for (final attachment in attachments)
                if (attachment != null)
                  SupportAttachment._fromJson(
                    read<Map<String, dynamic>>(attachment, 'attachments'),
                    readsBase64: false,
                  ),
            ],
    );
  }
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

  /// The result of `getMessageAttachment`. [fileData] is read from a byte
  /// array, a `{data: [...]}` buffer or a base64 string; any other value is
  /// `null`.
  factory SupportAttachment.fromJson(Map<String, dynamic> json) =>
      SupportAttachment._fromJson(json, readsBase64: true);

  factory SupportAttachment._fromJson(
    Map<String, dynamic> json, {
    required bool readsBase64,
  }) => SupportAttachment(
    attachmentId: read<String?>(json['attachmentId'], 'attachmentId'),
    fileName: read<String?>(json['fileName'], 'fileName'),
    fileType: read<String?>(json['fileType'], 'fileType'),
    fileSize: read<int?>(json['fileSize'], 'fileSize'),
    fileData: _fileData(json['fileData'], readsBase64: readsBase64),
    messageId: read<String?>(json['messageId'], 'messageId'),
    createdAt: _date(json['createdAt'], 'createdAt'),
  );
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

  Map<String, Object?> toJson() => {
    'fileName': fileName,
    'fileType': fileType,
    'fileSize': fileSize,
    'fileData': base64Encode(fileData),
  };
}

DateTime? _date(Object? value, String field) {
  final text = read<String?>(value, field);
  return text == null ? null : DateTime.tryParse(text);
}

Uint8List? _fileData(Object? value, {required bool readsBase64}) {
  switch (value) {
    case {'data': final Object data}:
      return _bytes(read<List<dynamic>>(data, 'fileData'));
    case final List<dynamic> list:
      return _bytes(list);
    case final String text when readsBase64:
      try {
        return base64Decode(text);
      } on FormatException {
        throw const BbxApiFormatException('invalid fileData');
      }
    default:
      return null;
  }
}

Uint8List _bytes(List<dynamic> list) =>
    Uint8List.fromList([for (final byte in list) read<int>(byte, 'fileData')]);
