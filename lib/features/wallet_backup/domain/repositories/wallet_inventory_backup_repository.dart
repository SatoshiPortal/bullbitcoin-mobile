import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/keychain_manifest/public/keychain_manifest_facade.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_inventory_recovery.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletInventoryBackupRepository {
  @useResult
  Future<Result<WalletInventoryRecovery, WalletBackupFailure>> restore(
    List<BackupWallet> wallets, {
    Map<String, String?> initialWalletLabels = const {},
  });
}
