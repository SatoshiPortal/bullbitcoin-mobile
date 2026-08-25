import 'package:bb_mobile/core/exchange/domain/entity/support_chat_message_attachment.dart';
import 'package:bb_mobile/core/exchange/domain/exchange_support_chat_failure.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/exchange_support_chat/data/photo_library_permission_datasource.dart';
import 'package:bb_mobile/features/exchange_support_chat/domain/repositories/attachment_picker_repository.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Why the photo library may not be read. Resolved once, up front, from the plugin's own status, never inferred afterwards from an exception message.
enum _PhotoLibraryAccess { granted, denied, permanentlyDenied }

class AttachmentPickerRepositoryImpl implements AttachmentPickerRepository {
  final ImagePicker _picker;
  final PhotoLibraryPermissionDatasource _permissions;

  /// The platform is injected rather than read from `Platform`, so both Android permission models (pre-13 storage, 13+ photos) are reachable from a test.
  final bool _isAndroid;

  AttachmentPickerRepositoryImpl({
    required this._permissions,
    required this._isAndroid,
    ImagePicker? picker,
  }) : _picker = picker ?? ImagePicker();

  @override
  Future<Result<List<SupportChatMessageAttachment>, ExchangeSupportChatFailure>>
  pickImages() async {
    try {
      switch (await _photoLibraryAccess()) {
        case _PhotoLibraryAccess.granted:
          break;
        case _PhotoLibraryAccess.denied:
          return const Err(PermissionDeniedFailure());
        case _PhotoLibraryAccess.permanentlyDenied:
          return const Err(PermissionDeniedNeedsSettingsFailure());
      }

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

  /// Only Android gates gallery access.
  ///
  /// On iOS the picker is a `PHPickerViewController`, which runs out of process and needs no photo-library grant at all. The deployment target is 15, so the pre-14 `UIImagePickerController` path that did check authorization is unreachable. Asking anyway would prompt every user for nothing and let a refusal block a picker that would have worked.
  Future<_PhotoLibraryAccess> _photoLibraryAccess() async {
    if (!_isAndroid) return _PhotoLibraryAccess.granted;

    final photos = await _resolve(Permission.photos);
    if (photos == _PhotoLibraryAccess.granted) return photos;

    // Android 12 and older serve the gallery through the legacy storage permission, so a refusal on `photos` alone is not the final answer.
    final storage = await _resolve(Permission.storage);
    if (storage == _PhotoLibraryAccess.granted) return storage;

    // Only send the user to the OS settings when neither route can still be granted in-app, since otherwise a retry is enough.
    return photos == _PhotoLibraryAccess.permanentlyDenied &&
            storage == _PhotoLibraryAccess.permanentlyDenied
        ? _PhotoLibraryAccess.permanentlyDenied
        : _PhotoLibraryAccess.denied;
  }

  Future<_PhotoLibraryAccess> _resolve(Permission permission) async {
    final status = await _permissions.status(permission);
    if (_isUsable(status)) return _PhotoLibraryAccess.granted;
    if (status.isPermanentlyDenied) {
      return _PhotoLibraryAccess.permanentlyDenied;
    }

    final requested = await _permissions.request(permission);
    if (_isUsable(requested)) return _PhotoLibraryAccess.granted;
    return requested.isPermanentlyDenied
        ? _PhotoLibraryAccess.permanentlyDenied
        : _PhotoLibraryAccess.denied;
  }

  /// `limited` is the iOS "selected photos" grant: the picker works, so it counts as access, and re-requesting it would only nag a user who already chose.
  bool _isUsable(PermissionStatus status) =>
      status.isGranted || status.isLimited;

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
