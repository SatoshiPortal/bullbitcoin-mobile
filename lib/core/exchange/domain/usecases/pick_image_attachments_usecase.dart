import 'package:bb_mobile/core/exchange/data/datasources/image_picker_datasource.dart';
import 'package:bb_mobile/core/exchange/data/datasources/permission_datasource.dart';
import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';

class PickImageAttachmentsResult {
  final List<SupportChatMessageAttachment> attachments;
  final PickImageError? error;

  const PickImageAttachmentsResult({
    this.attachments = const [],
    this.error,
  });

  bool get hasError => error != null;
}

enum PickImageError {
  permissionDenied,
  permissionPermanentlyDenied,
  pickFailed,
}

class PickImageAttachmentsUsecase {
  final ImagePickerDatasource _imagePickerDatasource;
  final PermissionDatasource _permissionDatasource;

  PickImageAttachmentsUsecase({
    required ImagePickerDatasource imagePickerDatasource,
    required PermissionDatasource permissionDatasource,
  })  : _imagePickerDatasource = imagePickerDatasource,
        _permissionDatasource = permissionDatasource;

  Future<PickImageAttachmentsResult> execute() async {
    // Check permission on Android
    if (_permissionDatasource.isAndroid) {
      final permissionResult =
          await _permissionDatasource.requestPhotoLibraryPermission();

      switch (permissionResult) {
        case PermissionResult.denied:
          return const PickImageAttachmentsResult(
            error: PickImageError.permissionDenied,
          );
        case PermissionResult.permanentlyDenied:
          return const PickImageAttachmentsResult(
            error: PickImageError.permissionPermanentlyDenied,
          );
        case PermissionResult.granted:
          break;
      }
    }

    try {
      final pickedImages = await _imagePickerDatasource.pickMultipleImages();

      if (pickedImages.isEmpty) {
        return const PickImageAttachmentsResult();
      }

      final attachments = pickedImages.map((image) {
        final fileType = _getFileType(image.fileName);
        return SupportChatMessageAttachment(
          attachmentId:
              'temp_attachment_${image.fileName}_${DateTime.now().millisecondsSinceEpoch}',
          fileName: image.fileName,
          fileType: fileType,
          fileSize: image.bytes.length,
          fileData: image.bytes,
          createdAt: DateTime.now(),
        );
      }).toList();

      return PickImageAttachmentsResult(attachments: attachments);
    } catch (e) {
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('permission') ||
          errorMessage.contains('denied')) {
        return const PickImageAttachmentsResult(
          error: PickImageError.permissionPermanentlyDenied,
        );
      }
      return const PickImageAttachmentsResult(
        error: PickImageError.pickFailed,
      );
    }
  }

  String _getFileType(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      default:
        return 'image/jpeg';
    }
  }
}

