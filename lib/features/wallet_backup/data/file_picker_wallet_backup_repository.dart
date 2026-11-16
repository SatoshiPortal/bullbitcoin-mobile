import 'dart:convert';
import 'dart:typed_data';

import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:file_picker/file_picker.dart';

/// Native file I/O only for new metadata files. Existing wallet/vault pickers
/// keep their owners and contracts.
final class FilePickerWalletBackupRepository
    implements WalletBackupFileRepository {
  final FilePickerPlatform _picker;
  const FilePickerWalletBackupRepository(this._picker);

  @override
  Future<Result<String?, WalletBackupFailure>> pick() async {
    try {
      final selected = await _picker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (selected.isEmpty) return const Ok(null);
      if (selected.length != 1) {
        return const Err(WalletBackupInvalidFailure());
      }
      final file = selected.single;
      if ((file.lengthSync() ?? 0) > WalletBackupFile.maximumBytes) {
        return const Err(WalletBackupTooLargeFailure());
      }
      final source = file.readAsByteStream();
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in source) {
        // Check before retaining a chunk; returning cancels the stream.
        if (bytes.length + chunk.length > WalletBackupFile.maximumBytes) {
          return const Err(WalletBackupTooLargeFailure());
        }
        bytes.add(chunk);
      }
      return Ok(utf8.decode(bytes.takeBytes()));
    } on FormatException {
      return const Err(WalletBackupInvalidFailure());
    } on Exception {
      return const Err(WalletBackupStorageFailure());
    }
  }

  @override
  Future<Result<bool, WalletBackupFailure>> save(
    String source, {
    required WalletBackupFileFormat format,
  }) async {
    if (source.length > WalletBackupFile.maximumBytes) {
      return const Err(WalletBackupTooLargeFailure());
    }
    final bytes = utf8.encode(source);
    if (bytes.length > WalletBackupFile.maximumBytes) {
      return const Err(WalletBackupTooLargeFailure());
    }
    try {
      final saved = await _picker.saveFile(
        mimeType: 'application/json',
        fileName: 'bullbitcoin-data-backup-${format.name}.json',
        bytes: bytes,
      );
      return Ok(saved != null);
    } on Exception {
      return const Err(WalletBackupStorageFailure());
    }
  }
}
