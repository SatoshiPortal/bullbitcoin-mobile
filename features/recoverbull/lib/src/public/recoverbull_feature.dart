import 'package:secrets/secrets.dart';

import '../data/secrets_vault_repository.dart';
import '../domain/recoverbull_wallet_port.dart';
import '../domain/usecases/create_vault_usecase.dart';
import '../domain/usecases/restore_vault_usecase.dart';
import '../domain/usecases/test_vault_usecase.dart';
import 'recoverbull_facade.dart';

/// Composition stays separate from the feature's business interface.
final class RecoverBullFeature {
  final RecoverBullFacade facade;

  const RecoverBullFeature._(this.facade);

  factory RecoverBullFeature.create({
    required Secrets secrets,
    required RecoverBullWalletPort wallets,
  }) {
    final vaults = SecretsVaultRepository(secrets);
    return RecoverBullFeature._(
      RecoverBullFacade(
        CreateVaultUsecase(vaults, wallets),
        TestVaultUsecase(vaults, wallets),
        RestoreVaultUsecase(vaults, wallets),
      ),
    );
  }
}
