import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange_support_chat/domain/repositories/attachment_picker_repository.dart';
import 'package:image_picker/image_picker.dart';

class AttachmentPickerRepositoryImpl implements AttachmentPickerRepository {
  final ImagePicker _picker;

  AttachmentPickerRepositoryImpl({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  /// Reading the gallery needs no permission on either platform.
  ///
  /// `image_picker` hands the selection to an out-of-process picker that grants
  /// read access to the chosen items only: `PHPickerViewController` on iOS, and
  /// `PickVisualMedia` / `ACTION_GET_CONTENT` on Android. The one permission the
  /// plugin ever checks is `CAMERA`, and only for capture, which this call never
  /// reaches.
  @override
  Future<Result<List<SupportChatMessageAttachment>, ExchangeSupportChatFailure>>
  pickImages() async {
    try {
      final images = await _picker.pickMultiImage();
      return Ok([for (final image in images) await _toAttachment(image)]);
    } catch (e, st) {
      log.warning(
        'Failed to pick support chat attachments',
        error: e,
        trace: st,
      );
      return Err(PickFilesFailure('$e'));
    }
  }

  Future<SupportChatMessageAttachment> _toAttachment(XFile image) async {
    final bytes = await image.readAsBytes();
    final fileName = image.name;
    return SupportChatMessageAttachment(
      attachmentId:
          'temp_attachment_${fileName}_${DateTime.now().millisecondsSinceEpoch}',
      fileName: fileName,
      fileType: _fileType(fileName),
      fileSize: bytes.length,
      fileData: bytes,
      createdAt: DateTime.now(),
    );
  }

  String _fileType(String fileName) =>
      switch (fileName.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };
}
