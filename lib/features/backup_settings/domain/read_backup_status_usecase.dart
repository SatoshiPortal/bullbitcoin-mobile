import 'package:bb_mobile/features/wallet/domain/network_x.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:primitives/primitives.dart';

import 'backup_settings_failure.dart';

final class BackupStatusSummary {
  final bool physicalVerified;
  final bool encryptedVerified;

  /// An encrypted backup from before the current backup system, never stored or tested since.
  final bool encryptedHistorical;
  final DateTime? physicalAt;
  final DateTime? encryptedAt;
  const BackupStatusSummary({
    this.physicalVerified = false,
    this.encryptedVerified = false,
    this.encryptedHistorical = false,
    this.physicalAt,
    this.encryptedAt,
  });
}

final class ReadBackupStatusUsecase {
  final GetWalletsUsecase _wallets;
  final Preferences _settings;
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
      final settings = (await _settings.fetch()).fold(
        (value) => value,
        (failure) => throw Exception('Preferences read failed'),
      );
      final List<Wallet> wallets;
      switch (await _wallets.execute(onlyDefaults: true)) {
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
                wallet.network.environment == settings.environment.networkEnv,
          )
          .firstOrNull;
      if (bitcoin == null) return const Ok(BackupStatusSummary());
      final status = await _backupStatus(
        rb.VaultContext(
          fingerprint: Fingerprint(bitcoin.masterFingerprint),
          network: bitcoin.network.bitcoin,
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
          encryptedHistorical:
              current?.storedAt == null &&
              current?.verifiedAt == null &&
              bitcoin.latestEncryptedBackup != null,
          physicalAt: bitcoin.latestPhysicalBackup,
          // The old date keeps access available, never the verification badge.
          encryptedAt:
              current?.storedAt ??
              current?.verifiedAt ??
              bitcoin.latestEncryptedBackup,
        ),
      );
    } on Exception {
      return const Err(BackupSettingsUnexpectedFailure());
    }
  }
}
