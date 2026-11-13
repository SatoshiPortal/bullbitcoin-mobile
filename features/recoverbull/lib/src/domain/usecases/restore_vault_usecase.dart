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
  }) async {
    if (cancelled()) return const Err(VaultCancelledFailure());
    // Once this call begins, cancellation cannot undo a keystore import.
    // Finish accounting for it; the presenter suppresses late callbacks.
    switch (await _vaults.restore(vault, key)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final requested = VaultContext(fingerprint: value, network: network);
        switch (await _wallets.restoreDefaults(requested)) {
          case Err(:final failure):
            return Ok(VaultRecoveryNeedsWallets(value, failure));
          case Ok(value: final restored):
            if (!restored.matches(requested)) {
              return Ok(
                VaultRecoveryNeedsWallets(
                  value,
                  const VaultContextChangedFailure(),
                ),
              );
            }
            return Ok(VaultRecovered(restored));
        }
    }
  }
}
