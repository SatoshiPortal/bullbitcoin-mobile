import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletMetadataBackupRepository {
  Stream<void> get changes;

  @useResult
  Future<Result<WalletMetadataBackup, WalletBackupFailure>> capture(
    Map<String, String> walletReferences,
  );
}
