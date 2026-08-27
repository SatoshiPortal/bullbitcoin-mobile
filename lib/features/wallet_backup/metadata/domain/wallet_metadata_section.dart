import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_apply.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_inventory.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletMetadataBackup {
  @useResult
  Future<Result<WalletMetadataSnapshotInventory, WalletMetadataBackupFailure>>
  localInventory();

  @useResult
  Future<Result<String?, WalletMetadataBackupFailure>> compose({
    required String parentFingerprint,
    required String? remotePayload,
  });

  @useResult
  Future<Result<WalletMetadataRecoveryApplyResult, WalletMetadataBackupFailure>>
  recover({
    required String payload,
    required Set<String> createdWalletRefs,
    DateTime? deadline,
  });

  Stream<void> get changes;

  Future<void> dispose();
}
