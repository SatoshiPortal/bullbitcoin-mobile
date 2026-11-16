import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../entities/encrypted_vault.dart';
import '../entities/vault_context.dart';
import '../entities/vault_recovery.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_wallet_port.dart';
import '../repositories/vault_repository.dart';

final class RestoreVaultUsecase {
  final VaultRepository _vaults;
  final RecoverBullWalletPort _wallets;

  const RestoreVaultUsecase(this._vaults, this._wallets);

  Future<Result<VaultRecovery, RecoverBullFailure>> execute({
    required EncryptedVault vault,
    required VaultKey key,
    required BitcoinNetwork network,
    required bool Function() cancelled,
    String passphrase = '',
    bool allowUnverified = false,
  }) async {
    if (cancelled()) return const Err(VaultCancelledFailure());
    // Once this call begins, cancellation cannot undo a keystore import.
    // Finish accounting for it; the presenter suppresses late callbacks.
    switch (await _vaults.restore(
      vault,
      key,
      passphrase: passphrase,
      allowUnverified: allowUnverified,
    )) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return Ok(await _createWallets(value, network));
    }
  }

  /// Creates the wallets of a secret already imported, after a failed first try.
  Future<VaultRecovery> retryWallets(VaultRecoveryNeedsWallets recovery) =>
      _createWallets(recovery.importedSecret, recovery.network);

  Future<VaultRecovery> _createWallets(
    Fingerprint secret,
    BitcoinNetwork network,
  ) async {
    final requested = VaultContext(fingerprint: secret, network: network);
    switch (await _wallets.restoreDefaults(requested)) {
      case Err(:final failure):
        return VaultRecoveryNeedsWallets(secret, failure, network: network);
      case Ok(value: final restored):
        if (!restored.matches(requested)) {
          return VaultRecoveryNeedsWallets(
            secret,
            const VaultContextChangedFailure(),
            network: network,
          );
        }
        return VaultRecovered(restored);
    }
  }
}
