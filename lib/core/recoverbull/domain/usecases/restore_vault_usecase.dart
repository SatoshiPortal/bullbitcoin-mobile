import 'package:bb_mobile/core/recoverbull/domain/entity/encrypted_vault.dart';
import 'package:bb_mobile/core/recoverbull/domain/recoverbull_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:secrets/secrets.dart' as secrets;

/// If the key server is down
class RestoreVaultUsecase {
  final secrets.Secrets _secrets;
  final WalletRepository _walletRepository;
  final CreateDefaultWalletsUsecase _createDefaultWallets;

  RestoreVaultUsecase({
    required this._secrets,
    required this._walletRepository,
    required CreateDefaultWalletsUsecase createDefaultWalletsUsecase,
  }) : _createDefaultWallets = createDefaultWalletsUsecase;

  // Orchestrates the still-throwing wallet core repo; the local try/catch is
  // the boundary, mapping any failure to a sanitized core failure.
  Future<Result<Null, RecoverBullCoreFailure>> execute({
    required EncryptedVault vault,
    required String vaultKey,
  }) async {
    try {
      final result = await _secrets.recoverbull.restore(
        vault: secrets.EncryptedVault(json: vault.toFile()),
        key: secrets.VaultKey(vaultKey),
      );
      final secrets.Secret restoredSecret;
      switch (result) {
        case Ok(:final value):
          restoredSecret = value.secret;
        case Err():
          return const Err(
            RecoverBullUnexpectedCoreFailure('Vault restoration failed'),
          );
      }

      final restoredWallets = await _createDefaultWallets.execute(
        secret: restoredSecret,
      );

      for (final wallet in restoredWallets) {
        await _walletRepository.updateEncryptedBackupTime(
          time: DateTime.now(),
          walletId: wallet.id,
        );
      }

      log.fine('Vault restored');
      return const Ok(null);
    } catch (e, st) {
      log.severe(
        message: 'restoreVault failed',
        error: 'Vault restoration failed',
        trace: st,
      );
      return const Err(
        RecoverBullUnexpectedCoreFailure('Vault restoration failed'),
      );
    }
  }
}
