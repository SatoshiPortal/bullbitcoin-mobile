import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart';

/// Whether the user has an encrypted vault the app no longer tracks.
///
/// Encrypted backups were recorded on the wallet metadata before the
/// RecoverBull module took them over with its own store, and that record was
/// deliberately not migrated. Such a user is told once to recreate the vault:
/// a default mainnet wallet still carries the legacy record while RecoverBull
/// reports no encrypted backup. An unknown RecoverBull status, or any failure
/// to read either side, answers `false`, so the notice never shows on a guess.
class HasLegacyEncryptedVaultToRecreateUsecase {
  final WalletRepository _walletRepository;
  final Future<RecoverBullStatus> Function() _fetchRecoverBullStatus;

  HasLegacyEncryptedVaultToRecreateUsecase({
    required this._walletRepository,
    required this._fetchRecoverBullStatus,
  });

  Future<bool> execute() async {
    try {
      final status = await _fetchRecoverBullStatus();
      if (!status.isKnown || status.hasEncryptedBackup) return false;

      final wallets = await _walletRepository.getWallets(
        environment: Environment.mainnet,
        onlyDefaults: true,
      );
      return switch (wallets) {
        Ok(:final value) => value.any(
          (wallet) => wallet.latestEncryptedBackup != null,
        ),
        Err() => false,
      };
    } catch (e, st) {
      log.warning(
        'HasLegacyEncryptedVaultToRecreateUsecase failed',
        error: e,
        trace: st,
      );
      return false;
    }
  }
}
