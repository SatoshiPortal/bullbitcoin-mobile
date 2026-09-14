import 'package:bb_mobile/features/backup_settings/domain/usecases/recover_vaults_from_backup_words_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/vault_recovery_result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullvault/public/bullvault_facade.dart';
import 'package:bb_mobile/features/wallet_backup/public/wallet_backup_facade.dart';

/// Recovers everything the restored seed's backup credential can reach.
///
/// The Data Backup server comes first, then the vault descriptors published on
/// the relays, which the same twelve words open. Relay discovery follows the
/// Data Backup choice: a wallet whose backup is off or unreadable is not asked
/// to search the relays either.
///
/// [discoverVaults] and [vaults] are absent in tests of the metadata half
/// alone; without them nothing new happens.
Future<bool> recoverWalletDataAfterSeedRestore(
  WalletBackupFacade walletBackup, {
  required List<WalletPreferences> defaultCreatedWalletPreferences,
  RecoverVaultsFromBackupWordsUsecase? discoverVaults,
  BullVaultFacade? vaults,
}) async {
  try {
    final result = await walletBackup.recover(
      defaultCreatedWalletPreferences: defaultCreatedWalletPreferences,
    );
    final complete =
        result.status == WalletBackupRecoveryStatus.noBackup ||
        result.status == WalletBackupRecoveryStatus.restored;
    if (!complete) {
      log.warning(
        'Optional wallet backup recovery did not complete',
        error: result.status,
      );
      return false;
    }
    await _recoverVaultsFromRelays(discoverVaults, vaults);
    return true;
  } on Exception catch (error, stackTrace) {
    log.warning(
      'Optional wallet backup recovery failed',
      error: error.runtimeType,
      trace: stackTrace,
    );
    return false;
  }
}

/// A relay search that fails changes nothing: seed recovery already succeeded,
/// and the recovery screen can search again at any time.
Future<void> _recoverVaultsFromRelays(
  RecoverVaultsFromBackupWordsUsecase? discoverVaults,
  BullVaultFacade? vaults,
) async {
  if (discoverVaults == null) return;
  switch (await discoverVaults.fromNostr()) {
    case Err(:final failure):
      log.warning(
        'Optional vault descriptor discovery did not complete',
        error: failure.runtimeType,
      );
    case Ok(:final value):
      // Only a wallet that was actually persisted is worth announcing.
      final imported = value.outcomes.any(
        (outcome) => outcome.status == VaultRecoveryStatus.imported,
      );
      if (imported) vaults?.recordVaultRecovered();
  }
}
