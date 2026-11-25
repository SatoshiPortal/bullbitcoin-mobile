import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';

import 'recoverbull_wallet_backups.dart';

/// Whether a secret has a tested backup, read from the RecoverBull projection
/// of both network families. A seed is the same seed on every network, so the
/// active network is not a parameter: one positive proof in either store is
/// enough, and two backups are never required.
final class RecoverBullBackupVerification
    implements InventoryBackupVerification {
  final RecoverBullWalletBackups _backups;
  final RecoverBullWalletBackups _regtestBackups;

  const RecoverBullBackupVerification({
    required this._backups,
    required this._regtestBackups,
  });

  /// A positive proof wins even when the other store cannot be read. With no
  /// proof, an unreadable store means the state is unknown, never missing.
  @override
  Future<Result<BackupProof, SecretFailure>> verify(
    Fingerprint secret, {
    ({String walletId, bool regtest})? replacingWallet,
  }) async {
    var unreadable = false;
    for (final (store, regtest) in [
      (_backups, false),
      (_regtestBackups, true),
    ]) {
      switch (await store.projection(
        secret,
        excludingWalletId: replacingWallet?.regtest == regtest
            ? replacingWallet?.walletId
            : null,
      )) {
        case Ok(:final value):
          if (value.encryptedVaultTested || value.physicalBackupTested) {
            return const Ok(BackupProof.verified);
          }
        case Err():
          unreadable = true;
      }
    }
    return unreadable
        ? const Err(BackupStateUnavailableFailure())
        : const Ok(BackupProof.missing);
  }
}
