import 'dart:typed_data';

/// Repository contract for secure file uploads
abstract class SecureFileUploadRepository {
  /// Upload a file securely
  /// Returns the uploaded file ID on success
  /// The [onProgress] callback reports upload progress (0.0 to 1.0)
  Future<String> uploadFile({
    required String fileName,
    required Uint8List fileBytes,
    required String mimeType,
    void Function(double progress)? onProgress,
  });
}

