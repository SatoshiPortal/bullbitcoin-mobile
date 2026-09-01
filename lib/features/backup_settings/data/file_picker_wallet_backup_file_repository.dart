import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';
import 'package:file_picker/file_picker.dart';
import 'package:primitives/primitives.dart';

final class FilePickerWalletBackupFileRepository
    implements WalletBackupFileRepository {
  final FilePicker _picker;

  FilePickerWalletBackupFileRepository([FilePicker? picker])
    : _picker = picker ?? FilePicker.platform;

  @override
  Future<Result<bool, BackupSettingsFailure>> save(
    WalletBackupExport export,
  ) async {
    try {
      final bytes = export.copyBytes();
      final savedPath = await _picker.saveFile(
        bytes: bytes,
        fileName: export.suggestedFilename,
      );
      return Ok(savedPath != null);
    } on Exception catch (error, trace) {
      log.warning(
        'Could not save wallet backup file',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(BackupSettingsFileSaveFailure());
    }
  }

  @override
  Future<Result<Uint8List?, BackupSettingsFailure>> pick({
    required int maximumBytes,
  }) async {
    try {
      final result = await _picker.pickFiles(type: FileType.any);
      if (result == null) return const Ok(null);
      final file = result.files.single;
      if (file.size <= 0) {
        return const Err(BackupSettingsFileReadFailure());
      }
      if (file.size > maximumBytes) {
        return const Err(BackupSettingsFileTooLargeFailure());
      }
      final Uint8List bytes;
      if (file.bytes case final inMemory?) {
        bytes = inMemory;
      } else if (file.path case final filePath?) {
        final builder = BytesBuilder(copy: false);
        await for (final chunk in File(
          filePath,
        ).openRead(0, maximumBytes + 1)) {
          builder.add(chunk);
        }
        bytes = builder.takeBytes();
      } else {
        return const Err(BackupSettingsFileReadFailure());
      }
      if (bytes.length > maximumBytes) {
        return const Err(BackupSettingsFileTooLargeFailure());
      }
      if (bytes.isEmpty || bytes.length != file.size) {
        return const Err(BackupSettingsFileReadFailure());
      }
      return Ok(bytes);
    } on Exception catch (error, trace) {
      log.warning(
        'Could not read wallet backup file',
        error: error.runtimeType,
        trace: trace,
      );
      return const Err(BackupSettingsFileReadFailure());
    }
  }
}
