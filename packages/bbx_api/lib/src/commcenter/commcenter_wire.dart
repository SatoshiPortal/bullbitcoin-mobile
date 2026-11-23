import 'dart:convert';
import 'dart:typed_data';

import 'package:bbx_api/src/bbx_format_exception.dart';
import 'package:bbx_api/src/commcenter/announcement.dart';
import 'package:bbx_api/src/commcenter/support_message.dart';
import 'package:bbx_api/src/json.dart';

Announcement parseAnnouncement(Map<String, dynamic> json) {
  final updatedAt = DateTime.tryParse(
    read<String>(json['updatedAt'], 'updatedAt'),
  );
  if (updatedAt == null) {
    throw const BbxFormatException('invalid updatedAt');
  }
  return Announcement(
    title: read<String>(json['title'], 'title'),
    description: read<String>(json['description'], 'description'),
    updatedAt: updatedAt,
  );
}

/// Reads [SupportAttachment.fileData] only from a byte array: a base64
/// string is `null` here.
SupportMessage parseSupportMessage(Map<String, dynamic> json) {
  final attachments = read<List<dynamic>?>(json['attachments'], 'attachments');
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
                _parseSupportAttachment(
                  read<Map<String, dynamic>>(attachment, 'attachments'),
                  readsBase64: false,
                ),
          ],
  );
}

/// The result of `getMessageAttachment`. [SupportAttachment.fileData] is read from a byte
/// array, a `{data: [...]}` buffer or a base64 string; any other value is
/// `null`.
SupportAttachment parseSupportAttachment(Map<String, dynamic> json) =>
    _parseSupportAttachment(json, readsBase64: true);

SupportAttachment _parseSupportAttachment(
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

Map<String, Object?> newSupportAttachmentToJson(
  NewSupportAttachment attachment,
) => {
  'fileName': attachment.fileName,
  'fileType': attachment.fileType,
  'fileSize': attachment.fileSize,
  'fileData': base64Encode(attachment.fileData),
};

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
        throw const BbxFormatException('invalid fileData');
      }
    default:
      return null;
  }
}

Uint8List _bytes(List<dynamic> list) =>
    Uint8List.fromList([for (final byte in list) read<int>(byte, 'fileData')]);
