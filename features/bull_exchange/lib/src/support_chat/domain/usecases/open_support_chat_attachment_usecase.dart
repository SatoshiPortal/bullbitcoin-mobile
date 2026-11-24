import 'dart:io';

import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';
import 'package:path_provider/path_provider.dart';
import 'package:primitives/primitives.dart';
import 'package:share_plus/share_plus.dart';

import '../attachment_filename_sanitizer.dart';
import '../exchange_support_chat_failure.dart';
import 'get_support_chat_message_attachment_usecase.dart';

/// Downloads one attachment into the temp directory and opens the share
/// sheet for it.
class OpenSupportChatAttachmentUsecase {
  final GetSupportChatMessageAttachmentUsecase _getAttachment;
  final Future<Directory> Function() _temporaryDirectory;
  final Future<void> Function(String path, String subject) _share;

  OpenSupportChatAttachmentUsecase({
    required GetSupportChatMessageAttachmentUsecase getAttachment,
    Future<Directory> Function()? temporaryDirectory,
    Future<void> Function(String path, String subject)? share,
  }) : _getAttachment = getAttachment,
       _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _share = share ?? _shareFile;

  static Future<void> _shareFile(String path, String subject) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(path)], subject: subject),
    );
  }

  @useResult
  Future<Result<void, ExchangeSupportChatFailure>> execute(
    String attachmentId,
  ) async {
    switch (await _getAttachment.execute(attachmentId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final bytes = value.fileData;
        final fileName = value.fileName;
        if (bytes == null || fileName == null) {
          return const Err(FetchFileDataFailure());
        }
        // Writing the temp file and opening the share sheet is foreign IO
        // (share_plus throws on some devices/iPad popover cases).
        try {
          final tempDir = await _temporaryDirectory();
          // fileName is server-controlled input: never let it become path
          // material beyond a bare filename (path traversal).
          final safeFileName = sanitizeAttachmentFileName(
            fileName,
            attachmentId: attachmentId,
          );
          final tempFile = File('${tempDir.path}/$safeFileName');
          await tempFile.writeAsBytes(bytes);
          await _share(tempFile.path, fileName);
          return const Ok(null);
        } catch (e, st) {
          log.warning(
            'Failed to open support chat attachment',
            error: e.runtimeType,
            trace: st,
          );
          return Err(LoadAttachmentFailure('${e.runtimeType}'));
        }
    }
  }
}
