import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_encryption.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_backup_remote.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_backup_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:crypto/crypto.dart';

final class FetchWalletBackupRemoteUsecase {
  final WalletBackupRemoteRepository _repository;
  final WalletBackupAuthenticator _authenticator;

  const FetchWalletBackupRemoteUsecase(this._repository, this._authenticator);

  Future<Result<WalletBackupRemoteHead, WalletBackupFailure>> execute() async {
    final authentication = await _authenticator.sign(
      action: WalletBackupAction.fetch,
      generation: 0,
      expectedEtag: '',
      ciphertextSha256: '',
      ciphertextBytes: 0,
    );
    return switch (authentication) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _repository.fetch(authentication: value),
    };
  }
}

final class StoreWalletBackupRemoteUsecase {
  final WalletBackupRemoteRepository _repository;
  final WalletBackupAuthenticator _authenticator;

  const StoreWalletBackupRemoteUsecase(this._repository, this._authenticator);

  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> execute({
    required WalletBackupRemoteCheckpoint? current,
    required WalletBackupCiphertext ciphertext,
  }) async {
    final generation = (current?.generation ?? 0) + 1;
    final hash = sha256.convert(base64.decode(ciphertext.value)).toString();
    final authentication = await _authenticator.sign(
      action: WalletBackupAction.store,
      generation: generation,
      expectedEtag: current?.etag ?? '',
      ciphertextSha256: hash,
      ciphertextBytes: ciphertext.byteLength,
    );
    return switch (authentication) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _repository.store(
        authentication: value,
        current: current,
        ciphertext: ciphertext,
        ciphertextSha256: hash,
      ),
    };
  }
}

final class DeleteWalletBackupRemoteUsecase {
  final WalletBackupRemoteRepository _repository;
  final WalletBackupAuthenticator _authenticator;

  const DeleteWalletBackupRemoteUsecase(this._repository, this._authenticator);

  /// Deletes the remote object, or reports the tombstone [current] already is.
  Future<Result<WalletBackupRemoteCheckpoint, WalletBackupFailure>> execute({
    required WalletBackupRemoteCheckpoint current,
  }) async {
    if (!current.found) return Ok(current);
    final authentication = await _authenticator.sign(
      action: WalletBackupAction.delete,
      generation: current.generation + 1,
      expectedEtag: current.etag,
      ciphertextSha256: '',
      ciphertextBytes: 0,
    );
    return switch (authentication) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _repository.delete(
        authentication: value,
        current: current,
      ),
    };
  }
}
