import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/private_descriptor_record.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/private_descriptor_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:crypto/crypto.dart';

typedef EncodePrivateDescriptorBackup =
    Future<Result<BullVaultDescriptorBackup, BullVaultFailure>> Function(
      String walletId,
    );
typedef DeriveDescriptorLookupToken = String? Function(String accountKeyInput);

/// Publishes one vault descriptor, sealed for its own cosigners.
///
/// The record is immutable and addressed by its ciphertext hash, so re-sending
/// the same bytes is idempotent. Sealing afresh is not: a fresh nonce is a
/// different record. A caller that has already written its artifact down passes
/// it as [prepared], and every retry then reaches the same record; without one
/// this use case seals the vault's descriptor itself, for a first publication
/// that nothing has to survive.
final class PublishPrivateDescriptorUsecase {
  final EncodePrivateDescriptorBackup _encode;
  final WalletBackupAuthenticator _authenticator;
  final PrivateDescriptorRemoteRepository _remote;

  const PublishPrivateDescriptorUsecase(
    this._encode,
    this._authenticator,
    this._remote,
  );

  /// The creation time the server assigned, which is the original one when the
  /// same record was already stored.
  Future<Result<DateTime, WalletBackupFailure>> execute(
    String walletId, {
    BullVaultDescriptorBackup? prepared,
  }) async {
    final BullVaultDescriptorBackup backup;
    if (prepared != null) {
      backup = prepared;
    } else {
      switch (await _encode(walletId)) {
        case Err(:final failure):
          return Err(WalletBackupVaultsFailure(failure.runtimeType.toString()));
        case Ok(:final value):
          backup = value;
      }
    }
    final ciphertext = Uint8List.fromList(backup.bytes);
    final authentication = await _authenticator.signDescriptorStore(
      ciphertextSha256: sha256.convert(ciphertext).toString(),
      ciphertextBytes: ciphertext.length,
      lookupTokens: backup.lookupTokens,
    );
    return switch (authentication) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _remote.store(
        authentication: value,
        ciphertext: ciphertext,
        lookupTokens: backup.lookupTokens,
      ),
    };
  }
}

/// Finds every descriptor record published under one cosigner's account key.
///
/// The results are candidates, not answers: the server cannot tell whether a
/// record belongs to the token it was filed under, so the caller decrypts and
/// proves membership. An empty result says nothing about whether the vault was
/// ever published.
final class LookupPrivateDescriptorsUsecase {
  final DeriveDescriptorLookupToken _lookupToken;
  final PrivateDescriptorRemoteRepository _remote;

  const LookupPrivateDescriptorsUsecase(this._lookupToken, this._remote);

  Future<Result<PrivateDescriptorLookup, WalletBackupFailure>> execute(
    String accountKeyInput,
  ) async {
    final token = _lookupToken(accountKeyInput);
    if (token == null) {
      return const Err(WalletBackupInvalidAccountKeyFailure());
    }
    return _remote.lookup([token]);
  }
}
