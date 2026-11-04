import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:wallet/wallet.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Reads from the wallet repo directly so callers can verify backup state
/// against the DB rather than a potentially-stale bloc cache.
class CheckBackupNeededUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;

  CheckBackupNeededUsecase({
    required this._walletRepository,
    required this._settingsRepository,
  });

  @useResult
  Future<Result<bool, WalletFailure>> execute() async {
    final Environment environment;
    try {
      environment = (await _settingsRepository.fetch()).environment;
    } catch (e, st) {
      log.severe(message: 'CheckBackupNeeded: settings', error: e, trace: st);
      return Err(WalletStorageFailure('settings fetch: ${e.runtimeType}'));
    }

    final List<Wallet> defaultWallets;
    switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      isMainnet: environment.isMainnet,
    )) {
      case Ok(:final value):
        defaultWallets = value;
      case Err(:final failure):
        return Err(failure);
    }

    return Ok(
      defaultWallets.isNotEmpty &&
          defaultWallets.any(
            (wallet) =>
                !wallet.isEncryptedVaultTested &&
                !wallet.isPhysicalBackupTested,
          ),
    );
  }
}
