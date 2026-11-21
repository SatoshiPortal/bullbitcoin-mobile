import 'dart:io' show PathNotFoundException;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import 'file_system_failure.dart';

/// Document selection and saving through the platform's native picker.
class FileSystem {
  final FilePickerPlatform? _picker;

  const FileSystem.open() : this._();

  const FileSystem._([this._picker]);

  FilePickerPlatform get _platform => _picker ?? FilePickerPlatform.instance;

  /// An empty extension list uses the system's unrestricted file picker.
  /// A null document indicates that the user dismissed the picker.
  @useResult
  Future<Result<PickedDocument?, FileSystemFailure>> pick({
    List<String> allowedExtensions = const [],
  }) async {
    try {
      final file = allowedExtensions.isEmpty
          ? await _platform.pickFile(type: FileType.any)
          : await _platform.pickFile(
              type: FileType.custom,
              allowedExtensions: allowedExtensions,
            );
      if (file == null) return const Ok(null);
      return Ok(PickedDocument._(file));
    } on Exception catch (error) {
      return Err(FileSystemPickFailure('${error.runtimeType}'));
    }
  }

  /// Reads bytes from a selected document, stopping once [maxBytes] is exceeded.
  @useResult
  Future<Result<Uint8List, FileSystemFailure>> read(
    PickedDocument document, {
    required int maxBytes,
  }) async {
    try {
      final data = BytesBuilder(copy: false);
      await for (final chunk in document._file.readAsByteStream()) {
        if (chunk.length > maxBytes - data.length) {
          return const Err(FileSystemTooLargeFailure());
        }
        data.add(chunk);
      }
      return Ok(data.takeBytes());
    } on PathNotFoundException {
      return const Err(FileSystemMissingFailure());
    } on Exception catch (error) {
      return Err(FileSystemReadFailure('${error.runtimeType}'));
    }
  }

  /// Returns false when the user dismisses the native save dialog.
  @useResult
  Future<Result<bool, FileSystemFailure>> save({
    required String filename,
    required Uint8List bytes,
    String mimeType = 'application/octet-stream',
  }) async {
    try {
      final uri = await _platform.saveFile(
        bytes: bytes,
        fileName: filename,
        mimeType: mimeType,
      );
      return Ok(uri != null);
    } on Exception catch (error) {
      return Err(FileSystemSaveFailure('${error.runtimeType}'));
    }
  }

  /// Clears picker-managed copies on platforms that create them.
  @useResult
  Future<Result<void, FileSystemFailure>> clearTemporaryFiles() async {
    try {
      await _platform.clearTemporaryFiles();
      return const Ok(null);
    } on UnimplementedError {
      return const Ok(null);
    } on Exception catch (error) {
      return Err(FileSystemCleanupFailure('${error.runtimeType}'));
    }
  }
}

class PickedDocument {
  final PlatformFile _file;

  const PickedDocument._(this._file);

  String get name => _file.name;
  String? get extension => _file.extension;
  String? get path => _file.path;
}

/// Opens the document transport with a substitute for the platform picker.
@visibleForTesting
FileSystem openFileSystemForTesting({required FilePickerPlatform picker}) =>
    FileSystem._(picker);
