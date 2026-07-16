import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

typedef WalletMetadataBackupStateUpdate =
    WalletMetadataBackupState Function(WalletMetadataBackupState current);

abstract interface class WalletMetadataBackupStateRepository {
  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  fetch();

  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>> update(
    WalletMetadataBackupStateUpdate update,
  );
}
