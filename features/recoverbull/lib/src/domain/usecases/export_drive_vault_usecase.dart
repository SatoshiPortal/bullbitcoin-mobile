import 'dart:convert';

import 'package:file_system/file_system.dart';
import 'package:primitives/primitives.dart';

import '../entities/drive_file_metadata.dart';
import '../recoverbull_failure.dart';
import '../repositories/google_drive_repository.dart';

final class ExportDriveVaultUsecase {
  final FileSystem _files;
  final GoogleDriveRepository _drive;
  const ExportDriveVaultUsecase(this._files, this._drive);
  Future<Result<void, RecoverBullFailure>> execute(
    DriveFileMetadata file,
  ) async {
    switch (await _drive.fetchRawFile(file)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return switch (await _files.save(
          filename: file.name,
          mimeType: 'application/json',
          bytes: utf8.encode(value),
        )) {
          Ok(value: true) => const Ok(null),
          Ok(value: false) => const Err(VaultCancelledFailure()),
          Err() => const Err(RecoverBullUnexpectedFailure()),
        };
    }
  }
}
