import 'package:bb_mobile/core/exchange/data/datasources/file_share_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/usecases/get_support_chat_message_attachment_usecase.dart';

class ShareAttachmentUsecase {
  final GetSupportChatMessageAttachmentUsecase _getAttachmentUsecase;
  final FileShareDatasource _fileShareDatasource;

  ShareAttachmentUsecase({
    required GetSupportChatMessageAttachmentUsecase getAttachmentUsecase,
    required FileShareDatasource fileShareDatasource,
  })  : _getAttachmentUsecase = getAttachmentUsecase,
        _fileShareDatasource = fileShareDatasource;

  Future<void> execute(String attachmentId) async {
    final attachment = await _getAttachmentUsecase.execute(attachmentId);

    if (attachment.fileData == null || attachment.fileName == null) {
      throw ShareAttachmentException('Failed to fetch file data');
    }

    await _fileShareDatasource.shareFile(
      fileData: attachment.fileData!,
      fileName: attachment.fileName!,
    );
  }
}

class ShareAttachmentException implements Exception {
  final String message;
  ShareAttachmentException(this.message);

  @override
  String toString() => message;
}
