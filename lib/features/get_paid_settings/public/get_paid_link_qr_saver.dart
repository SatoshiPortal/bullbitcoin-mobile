import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:meta/meta.dart';

/// Outcome of a Get Paid link QR PNG download.
enum QrImageSaveOutcome {
  /// The user chose a destination and the file was written.
  saved,

  /// The user dismissed the system save dialog — a NEUTRAL result (no error).
  cancelled,

  /// Writing the file failed.
  failed,
}

/// Saves a rendered QR PNG through the system Files save dialog. No gallery or
/// broad-storage permission is requested (the picker owns the destination), and
/// the URL / QR contents / chosen path are never logged.
///
/// It lives beside `GetPaidLinkQr` because it exists only as that widget's
/// injected save seam.
abstract interface class GetPaidLinkQrSaver {
  Future<QrImageSaveOutcome> save({
    required Uint8List pngBytes,
    required String fileName,
  });
}

/// `file_picker`-backed saver using the same `saveFile(bytes:)` idiom as CSV export.
/// A null result means the user cancelled; a recoverable [Exception] means the write failed.
/// Programmer [Error]s escape to the application's error reporting boundary.
/// Nothing here is logged.
class FilePickerGetPaidLinkQrSaver implements GetPaidLinkQrSaver {
  const FilePickerGetPaidLinkQrSaver();

  @override
  Future<QrImageSaveOutcome> save({
    required Uint8List pngBytes,
    required String fileName,
  }) {
    return mapSaveDialogResult(
      () => FilePicker.platform.saveFile(bytes: pngBytes, fileName: fileName),
    );
  }
}

/// Runs a system save dialog and maps a null path to neutral cancellation and a recoverable [Exception] to failure.
/// Programmer [Error]s escape instead of being converted into expected operational failures.
/// This seam permits unit testing without a platform-channel mock and never logs the URL, bytes, or destination.
@visibleForTesting
Future<QrImageSaveOutcome> mapSaveDialogResult(
  Future<String?> Function() saveFile,
) async {
  try {
    final result = await saveFile();
    return result == null
        ? QrImageSaveOutcome.cancelled
        : QrImageSaveOutcome.saved;
  } on Exception {
    return QrImageSaveOutcome.failed;
  }
}
