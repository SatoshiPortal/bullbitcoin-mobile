import 'package:primitives/primitives.dart';

import '../entities/vault_backup.dart';
import '../recoverbull_failure.dart';
import '../recoverbull_wallet_port.dart';
import '../repositories/vault_repository.dart';

final class CreateVaultUsecase {
  final VaultRepository _vaults;
  final RecoverBullWalletPort _wallets;

  const CreateVaultUsecase(this._vaults, this._wallets);

  Future<Result<VaultBackup, RecoverBullFailure>> execute() async {
    switch (await _wallets.currentDefault()) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: null):
        return const Err(VaultWalletMissingFailure());
      case Ok(value: final context?):
        return _vaults.create(context);
    }
  }
}
