import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:primitives/primitives.dart';
import 'backup_settings_failure.dart';

final class BackupStatusSummary {
  final bool physicalVerified;
  final bool encryptedVerified;
  final DateTime? physicalAt;
  final DateTime? encryptedAt;
  const BackupStatusSummary({
    this.physicalVerified = false,
    this.encryptedVerified = false,
    this.physicalAt,
    this.encryptedAt,
  });
}

final class ReadBackupStatusUsecase {
  final GetWalletsUsecase _wallets;
  final SettingsRepository _settings;
  final Future<Result<rb.BackupStatus, rb.RecoverBullFailure>> Function(
    rb.VaultContext,
  )
  _backupStatus;

  const ReadBackupStatusUsecase(
    this._wallets,
    this._settings,
    this._backupStatus,
  );

  Future<Result<BackupStatusSummary, BackupSettingsFailure>> execute() async {
    try {
      final settings = await _settings.fetch();
      final List<Wallet> wallets;
      switch (await _wallets.execute(
        onlyDefaults: true,
        onlyBitcoin: true,
        includeHidden: true,
      )) {
        case Err(failure: NoWalletsFoundFailure()):
          return const Ok(BackupStatusSummary());
        case Err():
          return const Err(BackupSettingsUnexpectedFailure());
        case Ok(:final value):
          wallets = value;
      }
      final bitcoin = wallets
          .where(
            (wallet) =>
                wallet.network.isBitcoin &&
                wallet.network.isTestnet == settings.environment.isTestnet,
          )
          .firstOrNull;
      if (bitcoin == null) return const Ok(BackupStatusSummary());
      final status = await _backupStatus(
        rb.VaultContext(
          fingerprint: Fingerprint(bitcoin.masterFingerprint),
          network: bitcoin.network.isTestnet
              ? BitcoinNetwork.testnet
              : BitcoinNetwork.mainnet,
        ),
      );
      final current = switch (status) {
        Ok(:final value) => value,
        Err() => null,
      };
      return Ok(
        BackupStatusSummary(
          physicalVerified: bitcoin.isPhysicalBackupTested,
          encryptedVerified: current?.isVerified ?? false,
          physicalAt: bitcoin.latestPhysicalBackup,
          // The old date keeps access available, never the verification badge.
          encryptedAt:
              current?.verifiedAt ??
              current?.storedAt ??
              bitcoin.latestEncryptedBackup,
        ),
      );
    } on Exception {
      return const Err(BackupSettingsUnexpectedFailure());
    }
  }
}
