import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_file.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_file_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:file_picker/file_picker.dart';

/// Native file I/O only for new metadata files. Existing wallet/vault pickers
/// keep their owners and contracts.
final class FilePickerWalletBackupRepository
    implements WalletBackupFileRepository {
  final FilePicker _picker;
  const FilePickerWalletBackupRepository(this._picker);

  @override
  Future<Result<String?, WalletBackupFailure>> pick() async {
    try {
      final selected = await _picker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: false,
        withReadStream: true,
      );
      if (selected == null || selected.files.isEmpty) return const Ok(null);
      if (selected.files.length != 1) {
        return const Err(WalletBackupInvalidFailure());
      }
      final file = selected.files.single;
      if (file.size > WalletBackupFile.maximumBytes) {
        return const Err(WalletBackupTooLargeFailure());
      }
      final Stream<List<int>> source;
      if (file.readStream != null) {
        source = file.readStream!;
      } else if (file.path != null) {
        source = File(file.path!).openRead();
      } else if (file.bytes != null) {
        if (file.bytes!.length > WalletBackupFile.maximumBytes) {
          return const Err(WalletBackupTooLargeFailure());
        }
        source = Stream.value(file.bytes!);
      } else {
        return const Err(WalletBackupStorageFailure());
      }
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
        fileName: 'bullbitcoin-data-backup-${format.name}.json',
        bytes: bytes,
      );
      return Ok(saved != null);
    } on Exception {
      return const Err(WalletBackupStorageFailure());
    }
  }
}
