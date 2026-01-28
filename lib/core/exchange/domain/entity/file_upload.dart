/// Entity representing a file to be uploaded
class FileToUpload {
  final String fileName;
  final List<int> bytes;
  final int sizeInBytes;

  const FileToUpload({
    required this.fileName,
    required this.bytes,
    required this.sizeInBytes,
  });

  /// Maximum file size in bytes (10MB)
  static const int maxFileSizeBytes = 10 * 1024 * 1024;

  /// Maximum number of files that can be uploaded
  static const int maxFileCount = 1;

  /// Allowed file extensions
  static const List<String> allowedExtensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'gif',
    'heic',
  ];

  bool get isValidSize => sizeInBytes <= maxFileSizeBytes;

  String get extension {
    final parts = fileName.split('.');
    if (parts.length > 1) {
      return parts.last.toLowerCase();
    }
    return '';
  }

  bool get hasValidExtension => allowedExtensions.contains(extension);
}

/// Result of a file upload operation
class FileUploadResult {
  final String? documentId;
  final bool isSuccess;
  final String? errorMessage;

  const FileUploadResult({
    this.documentId,
    required this.isSuccess,
    this.errorMessage,
  });

  factory FileUploadResult.success({String? documentId}) {
    return FileUploadResult(documentId: documentId, isSuccess: true);
  }

  factory FileUploadResult.failure(String errorMessage) {
    return FileUploadResult(isSuccess: false, errorMessage: errorMessage);
  }
}

/// Status of a file in the upload queue
enum FileUploadStatus {
  pending,
  uploading,
  success,
  failed,
}

/// Entity representing a file in the upload process
class UploadingFile {
  final FileToUpload file;
  final FileUploadStatus status;
  final String? errorMessage;
  final int index;

  const UploadingFile({
    required this.file,
    required this.status,
    this.errorMessage,
    required this.index,
  });

  UploadingFile copyWith({
    FileToUpload? file,
    FileUploadStatus? status,
    String? errorMessage,
    int? index,
  }) {
    return UploadingFile(
      file: file ?? this.file,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      index: index ?? this.index,
    );
  }
}

/// Validation result for file uploads
class FileValidationResult {
  final bool isValid;
  final FileValidationError? error;

  const FileValidationResult({
    required this.isValid,
    this.error,
  });

  factory FileValidationResult.valid() {
    return const FileValidationResult(isValid: true);
  }

  factory FileValidationResult.invalid(FileValidationError error) {
    return FileValidationResult(isValid: false, error: error);
  }
}

/// Types of file validation errors
enum FileValidationError {
  fileTooLarge,
  invalidExtension,
  tooManyFiles,
  emptyFile,
}

extension FileValidationErrorX on FileValidationError {
  String get message {
    switch (this) {
      case FileValidationError.fileTooLarge:
        return 'File size exceeds 10MB limit';
      case FileValidationError.invalidExtension:
        return 'Invalid file type. Allowed: PDF, JPG, PNG, GIF, HEIC';
      case FileValidationError.tooManyFiles:
        return 'Only 1 file allowed';
      case FileValidationError.emptyFile:
        return 'File is empty';
    }
  }
}
