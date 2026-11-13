import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/encrypted_vault.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/repositories/vault_file_repository.dart';
import 'mappers/encrypted_vault_mapper.dart';

final class VaultFileRepositoryImpl implements VaultFileRepository {
  final FilePicker _picker;

  VaultFileRepositoryImpl({FilePicker? picker})
    : _picker = picker ?? FilePicker.platform;

  @override
  Future<Result<EncryptedVault, RecoverBullFailure>> pick() async {
    try {
      final result = await _picker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result == null) return const Err(VaultCancelledFailure());
      final path = result.files.single.path;
      if (path == null) return const Err(VaultInvalidFailure());
      final file = File(path);
      if (await file.length() > 2 * EncryptedVault.maxCiphertextBytes) {
        return const Err(VaultInvalidFailure());
      }
      return Ok(EncryptedVaultMapper.parse(await file.readAsString()));
    } on FormatException {
      return const Err(VaultInvalidFailure());
    } on ArgumentError {
      return const Err(VaultInvalidFailure());
    } on Exception {
      return const Err(RecoverBullUnexpectedFailure());
    }
  }

  @override
  Future<Result<void, RecoverBullFailure>> save(EncryptedVault vault) =>
      export(EncryptedVaultMapper.fromEntity(vault).toFile(), vault.filename);

  @override
  Future<Result<void, RecoverBullFailure>> export(
    String content,
    String filename,
  ) async {
    try {
      final saved = await _picker.saveFile(
        fileName: filename,
        bytes: Uint8List.fromList(utf8.encode(content)),
      );
      return saved == null
          ? const Err(VaultCancelledFailure())
          : const Ok(null);
    } on Exception {
      return const Err(RecoverBullUnexpectedFailure());
    }
  }
}
