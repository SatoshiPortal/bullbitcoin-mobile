import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../entities/encrypted_vault.dart';
import '../entities/vault_context.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_wallet_port.dart';
import '../repositories/vault_repository.dart';

final class TestVaultUsecase {
  final VaultRepository _vaults;
  final RecoverBullWalletPort _wallets;

  const TestVaultUsecase(this._vaults, this._wallets);

  Future<Result<VaultContext, RecoverBullFailure>> execute({
    required EncryptedVault vault,
    required VaultKey key,
    String passphrase = '',
  }) async {
    final VaultContext context;
    switch (await _wallets.currentDefault()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Err(VaultWalletMissingFailure());
      case Ok(value: final value?):
        context = value;
    }
    switch (await _vaults.fingerprint(vault, key, passphrase: passphrase)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value != context.fingerprint) {
          return const Err(VaultWalletMismatchFailure());
        }
        // The result identifies the wallet actually checked, never a later
        // selection or an identity asserted in the vault's metadata.
        return Ok(context);
    }
  }
}
