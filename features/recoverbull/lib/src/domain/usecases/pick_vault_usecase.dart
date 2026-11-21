import 'dart:convert';

import 'package:file_system/file_system.dart';
import 'package:primitives/primitives.dart';

import '../../data/mappers/encrypted_vault_mapper.dart';
import '../entities/encrypted_vault.dart';
import '../recoverbull_failure.dart';

final class PickVaultUsecase {
  final FileSystem _files;
  const PickVaultUsecase(this._files);
  Future<Result<EncryptedVault, RecoverBullFailure>> execute() async {
    final PickedDocument? document;
    switch (await _files.pick(allowedExtensions: ['json'])) {
      case Ok(:final value):
        document = value;
      case Err():
        return const Err(RecoverBullUnexpectedFailure());
    }
    if (document == null) return const Err(VaultCancelledFailure());
    if (document.path == null) return const Err(VaultInvalidFailure());

    switch (await _files.read(
      document,
      maxBytes: 2 * EncryptedVault.maxCiphertextBytes,
    )) {
      case Err(:final failure):
        return failure.kind == FileSystemFailureKind.tooLarge
            ? const Err(VaultInvalidFailure())
            : const Err(RecoverBullUnexpectedFailure());
      case Ok(:final value):
        try {
          return Ok(EncryptedVaultMapper.parse(utf8.decode(value)));
        } on FormatException {
          return const Err(VaultInvalidFailure());
        } on ArgumentError {
          return const Err(VaultInvalidFailure());
        }
    }
  }
}
