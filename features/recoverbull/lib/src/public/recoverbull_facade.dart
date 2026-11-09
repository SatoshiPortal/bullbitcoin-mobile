import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../domain/entities/encrypted_vault.dart';
import '../domain/entities/vault_backup.dart';
import '../domain/entities/vault_context.dart';
import '../domain/entities/vault_recovery.dart';
import '../domain/recoverbull_failure.dart';
import '../domain/usecases/create_vault_usecase.dart';
import '../domain/usecases/restore_vault_usecase.dart';
import '../domain/usecases/test_vault_usecase.dart';

final class RecoverBullFacade {
  final CreateVaultUsecase _create;
  final TestVaultUsecase _test;
  final RestoreVaultUsecase _restore;

  @internal
  const RecoverBullFacade(this._create, this._test, this._restore);

  Future<Result<VaultBackup, RecoverBullFailure>> create() => _create.execute();

  Future<Result<VaultContext, RecoverBullFailure>> test({
    required EncryptedVault vault,
    required VaultKey key,
  }) => _test.execute(vault: vault, key: key);

  Future<Result<VaultRecovery, RecoverBullFailure>> restore({
    required EncryptedVault vault,
    required VaultKey key,
    required BitcoinNetwork network,
    required bool Function() cancelled,
  }) => _restore.execute(
    vault: vault,
    key: key,
    network: network,
    cancelled: cancelled,
  );
}
