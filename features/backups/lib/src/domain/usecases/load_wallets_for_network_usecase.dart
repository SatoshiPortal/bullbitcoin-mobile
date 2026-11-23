import 'package:meta/meta.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';

import '../backup_records.dart';
import '../backup_wallet.dart';
import '../test_wallet_backup_failure.dart';

class LoadWalletsForNetworkUsecase {
  final WalletInventory _inventory;
  final ActiveEnvironmentReader _environment;
  final BackupRecords _records;

  const LoadWalletsForNetworkUsecase(
    this._inventory,
    this._environment,
    this._records,
  );

  @useResult
  Future<Result<List<BackupWallet>, TestWalletBackupFailure>> execute() async {
    final environment = await _environment.readActiveEnvironment();
    if (environment is! Ok<Environment, PreferencesFailure>) {
      return const Err(TestWalletBackupWalletsUnavailableFailure());
    }
    final network = backupNetwork(environment.value);
    final selection = await _inventory.walletsForNetwork(network);
    if (selection is! Ok<WalletSelection, SecretFailure>) {
      return const Err(TestWalletBackupWalletsUnavailableFailure());
    }
    final wallets = <BackupWallet>[];
    for (final registration in selection.value.wallets) {
      final fingerprint = registration.secretFingerprint;
      DateTime? physicalAt;
      if (fingerprint != null) {
        switch (await _records(network).projection(fingerprint)) {
          case Ok(:final value):
            physicalAt = backupDate(value.latestPhysicalBackup);
          case Err():
            return const Err(TestWalletBackupWalletsUnavailableFailure());
        }
      }
      wallets.add(
        BackupWallet(
          id: registration.id,
          network: network,
          isDefault: registration.isDefault,
          label: registration.label,
          fingerprint: fingerprint,
          latestPhysicalBackup: physicalAt,
        ),
      );
    }
    if (wallets.isEmpty) return const Err(TestWalletBackupNoWalletsFailure());
    return Ok(wallets);
  }
}
