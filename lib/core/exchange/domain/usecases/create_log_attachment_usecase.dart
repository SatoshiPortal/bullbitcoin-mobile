import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:intl/intl.dart';

class CreateLogAttachmentUsecase {
  Future<SupportChatMessageAttachment> execute() async {
    try {
      List<String> logs;
      try {
        logs = await log.readLogs();
      } catch (e) {
        logs = [
          'timestamp\tlevel\tmessage\terror\ttrace',
          '${DateTime.now().toIso8601String()}\tINFO\tNo logs file found or logs could not be read: $e\t\t',
        ];
      }

      if (logs.isEmpty) {
        logs = [
          'timestamp\tlevel\tmessage\terror\ttrace',
          '${DateTime.now().toIso8601String()}\tINFO\tNo logs have been recorded yet\t\t',
        ];
      }

      final logContent = logs.join('\n');
      final bytes = Uint8List.fromList(utf8.encode(logContent));

      final random = Random();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final randomAlphanumeric = String.fromCharCodes(
        Iterable.generate(
          8,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ),
      );

      final fileName = '$timestamp.BullLog.$randomAlphanumeric.txt';

      return SupportChatMessageAttachment(
        attachmentId: 'temp_logs_${DateTime.now().millisecondsSinceEpoch}',
        fileName: fileName,
        fileType: 'text/plain',
        fileSize: bytes.length,
        fileData: bytes,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      throw CreateLogAttachmentException('$e');
    }
  }
}

class CreateLogAttachmentException extends BullException {
  CreateLogAttachmentException(super.message);
}
