import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:bull_recoverbull/storage.dart' show SecretBackupProjection;
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import 'backup_records.dart';
import 'test_wallet_backup_failure.dart';

final class BackupStatusSummary {
  final bool physicalVerified;
  final bool encryptedVerified;
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
  final WalletInventory _inventory;
  final ActiveEnvironmentReader _environment;
  final Future<Result<SecretBackupProjection, rb.RecoverBullFailure>> Function(
    BitcoinNetwork,
    Fingerprint,
  )
  _readProjection;
  final Future<Result<rb.BackupStatus, rb.RecoverBullFailure>> Function(
    rb.VaultContext,
  )
  _vaultStatus;

  const ReadBackupStatusUsecase(
    this._inventory,
    this._environment,
    this._readProjection,
    this._vaultStatus,
  );

  Future<Result<BackupStatusSummary, TestWalletBackupFailure>> execute() async {
    final environment = await _environment.readActiveEnvironment();
    if (environment is! Ok<Environment, PreferencesFailure>) {
      return const Err(TestWalletBackupUnexpectedFailure());
    }
    final network = backupNetwork(environment.value);
    final selection = await _inventory.walletsForNetwork(network);
    if (selection is! Ok<WalletSelection, SecretFailure>) {
      return const Err(TestWalletBackupUnexpectedFailure());
    }
    final wallet = selection.value.defaultWallet;
    final fingerprint = wallet?.secretFingerprint;
    if (fingerprint == null) return const Ok(BackupStatusSummary());
    final facts = await _readProjection(network, fingerprint);
    if (facts is! Ok<SecretBackupProjection, rb.RecoverBullFailure>) {
      return const Err(TestWalletBackupUnexpectedFailure());
    }
    final projection = facts.value;
    final status = await _vaultStatus(
      rb.VaultContext(fingerprint: fingerprint, network: network),
    );
    final current = status.fold((value) => value, (_) => null);
    final historical = backupDate(projection.latestEncryptedBackup);
    return Ok(
      BackupStatusSummary(
        physicalVerified: projection.physicalBackupTested,
        encryptedVerified: current?.isVerified ?? false,
        encryptedHistorical:
            current?.storedAt == null &&
            current?.verifiedAt == null &&
            historical != null,
        physicalAt: backupDate(projection.latestPhysicalBackup),
        encryptedAt: current?.storedAt ?? current?.verifiedAt ?? historical,
      ),
    );
  }
}
