import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_backup_words_usecase.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

/// Recovers everything the restored seed's backup credential can reach.
///
/// The Data Backup server and the vault descriptors on the relays are two
/// independent sources that the same twelve words open, and each is asked
/// whatever the other answered: a server that is unreachable or a backup that
/// came back partial says nothing about what the relays hold, and the relays
/// are worth most exactly then.
///
/// The return value is the metadata half alone, because that is what the
/// recovery screen reports as incomplete.
///
/// [discoverVaults] and [vaults] are absent in tests of the metadata half
/// alone; without them no relay search runs and nothing is announced.
Future<bool> recoverWalletDataAfterSeedRestore(
  WalletBackupFacade walletBackup, {
  required List<WalletPreferences> defaultCreatedWalletPreferences,
  RecoverVaultsFromBackupWordsUsecase? discoverVaults,
  BullVaultFacade? vaults,
}) async {
  final vaultsBefore = await _vaultCount(vaults);
  var complete = false;
  try {
    final result = await walletBackup.recover(
      defaultCreatedWalletPreferences: defaultCreatedWalletPreferences,
    );
    complete =
        result.status == WalletBackupRecoveryStatus.noBackup ||
        result.status == WalletBackupRecoveryStatus.restored;
    if (!complete) {
      log.warning(
        'Optional wallet backup recovery did not complete',
        error: result.status,
      );
    }
  } on Exception catch (error, stackTrace) {
    log.warning(
      'Optional wallet backup recovery failed',
      error: error.runtimeType,
      trace: stackTrace,
    );
  }
  await _recoverVaultsFromRelays(discoverVaults);
  // The home notice is about vaults this device now holds and did not before,
  // whichever source put them there. Announcing a discovery instead would miss
  // a vault the metadata backup restored and announce one that never landed.
  final vaultsAfter = await _vaultCount(vaults);
  if (vaults != null &&
      vaultsBefore != null &&
      vaultsAfter != null &&
      vaultsAfter > vaultsBefore) {
    vaults.recordVaultRecovered();
  }
  return complete;
}

/// A relay search that fails changes nothing: seed recovery already succeeded,
/// and the recovery screen can search again at any time.
Future<void> _recoverVaultsFromRelays(
  RecoverVaultsFromBackupWordsUsecase? discoverVaults,
) async {
  if (discoverVaults == null) return;
  if (await discoverVaults.fromNostr() case Err(:final failure)) {
    log.warning(
      'Optional vault descriptor discovery did not complete',
      error: failure.runtimeType,
    );
  }
}

/// How many vaults this device holds, or null when it cannot be read.
///
/// A count that cannot be read is not evidence that nothing arrived, and it is
/// no evidence that something did either, so it announces nothing.
Future<int?> _vaultCount(BullVaultFacade? vaults) async {
  if (vaults == null) return null;
  return switch (await vaults.listRecords()) {
    Ok(:final value) => value.length,
    Err() => null,
  };
}
