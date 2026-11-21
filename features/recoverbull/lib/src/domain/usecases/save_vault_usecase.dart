import 'dart:convert';

import 'package:file_system/file_system.dart';
import 'package:primitives/primitives.dart';

import '../../data/mappers/encrypted_vault_mapper.dart';
import '../entities/encrypted_vault.dart';
import '../entities/vault_provider.dart';
import '../recoverbull_failure.dart';
import '../repositories/google_drive_repository.dart';

final class SaveVaultUsecase {
  final FileSystem _files;
  final GoogleDriveRepository _drive;

  const SaveVaultUsecase(this._files, this._drive);

  Future<Result<void, RecoverBullFailure>> execute(
    EncryptedVault vault,
    VaultProvider provider,
  ) async {
    if (provider != VaultProvider.googleDrive) {
      final content = EncryptedVaultMapper.fromEntity(vault).toFile();
      return switch (await _files.save(
        filename: vault.filename,
        mimeType: 'application/json',
        bytes: utf8.encode(content),
      )) {
        Ok(value: true) => const Ok(null),
        Ok(value: false) => const Err(VaultCancelledFailure()),
        Err() => const Err(RecoverBullUnexpectedFailure()),
      };
    }
    switch (await _drive.connect()) {
      case Err(:final failure):
        return Err(failure);
      case Ok():
        return _drive.store(vault);
    }
  }
}
