import 'dart:typed_data';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/private_descriptor_remote_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_protocol.dart';
import 'package:crypto/crypto.dart';

typedef EncodePrivateDescriptorBackup =
    Future<Result<BullVaultDescriptorBackup, BullVaultFailure>> Function(
      String walletId,
    );

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
