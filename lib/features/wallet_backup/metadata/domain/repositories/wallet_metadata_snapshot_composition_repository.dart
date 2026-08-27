import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_inventory.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_backup/metadata/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletMetadataSnapshotCompositionRepository {
  @useResult
  Result<WalletMetadataSnapshotInventory, WalletMetadataBackupFailure> compose({
    required List<WalletMetadataContributorInventory> contributors,
    required WalletMetadataRemoteHead? remoteHead,
  });
}
