import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:meta/meta.dart';

/// Reads from the wallet repo directly so callers can verify backup state
/// against the DB rather than a potentially-stale bloc cache.
class CheckBackupNeededUsecase {
  final WalletRepository _walletRepository;
  final SettingsRepository _settingsRepository;
  final Future<rb.Result<rb.BackupStatus, rb.RecoverBullFailure>> Function(
    rb.VaultContext,
  )
  _backupStatus;

  CheckBackupNeededUsecase({
    required this._walletRepository,
    required this._settingsRepository,
    required this._backupStatus,
  });

  @useResult
  Future<Result<bool, WalletFailure>> execute() async {
    final Environment environment;
    try {
      environment = (await _settingsRepository.fetch()).environment;
    } on Exception {
      log.warning('recoverbull.backup.status.unavailable');
      return const Err(WalletStorageFailure());
    }

    final List<Wallet> defaultWallets;
    switch (await _walletRepository.getWallets(
      onlyDefaults: true,
      environment: environment,
    )) {
      case Ok(:final value):
        defaultWallets = value;
      case Err(:final failure):
        return Err(failure);
    }

    if (defaultWallets.isEmpty ||
        defaultWallets.every((wallet) => wallet.isPhysicalBackupTested)) {
      return const Ok(false);
    }
    final bitcoin = defaultWallets
        .where((wallet) => wallet.network.isBitcoin)
        .firstOrNull;
    if (bitcoin == null) return const Ok(true);
    final status = await _backupStatus(
      rb.VaultContext(
        fingerprint: rb.Fingerprint(bitcoin.masterFingerprint),
        network: bitcoin.network.isTestnet
            ? rb.BitcoinNetwork.testnet
            : rb.BitcoinNetwork.mainnet,
      ),
    );
    // Unavailable metadata cannot certify a backup; its historical flag is
    // availability information, not evidence of a successful verification.
    return Ok(switch (status) {
      rb.Ok(:final value) => !value.isVerified,
      rb.Err() => true,
    });
  }
}
