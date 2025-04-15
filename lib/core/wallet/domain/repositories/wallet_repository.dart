import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/wallet/domain/entity/wallet.dart';

abstract class WalletRepository {
  Future<Wallet> createWallet({
    required Seed seed,
    required Network network,
    required ScriptType scriptType,
    String label,
    bool isDefault,
  });
  Future<Wallet> importWatchOnlyWallet({
    required String xpub,
    required Network network,
    required ScriptType scriptType,
    required String label,
  });
  Future<Wallet> getWallet(
    String origin, {
    bool sync = false,
  });
  // These should also sync the wallets before returning them
  Future<List<Wallet>> getWallets({
    Environment? environment,
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  });
  // TODO: The recoverbull backup functionality should be moved to the wallet repo
  // and instead of having the updateBackupInfo and updateEncryptedBackupTime methods,
  //  doing the restore and backup create through the Wallet repository should
  //  implicitly update the backup info and encrypted backup time of the metadata.
  Future<void> updateBackupInfo({
    required bool isEncryptedVaultTested,
    required bool isPhysicalBackupTested,
    required DateTime? latestEncryptedBackup,
    required DateTime? latestPhysicalBackup,
    required String origin,
  });
  Future<void> updateEncryptedBackupTime(
    DateTime time, {
    required String origin,
  });
}
