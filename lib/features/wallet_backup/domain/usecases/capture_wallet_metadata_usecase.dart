import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_backup/domain/entities/wallet_metadata_backup.dart';
import 'package:bb_mobile/features/wallet_backup/domain/repositories/wallet_metadata_backup_repository.dart';
import 'package:bb_mobile/features/wallet_backup/domain/wallet_backup_failure.dart';
import 'package:meta/meta.dart';

final class CaptureWalletMetadataUsecase {
  final WalletMetadataBackupRepository _repository;

  const CaptureWalletMetadataUsecase(this._repository);

  @useResult
  Future<Result<WalletMetadataBackup, WalletBackupFailure>> execute(
    Map<String, String> walletReferences,
  ) => _repository.capture(walletReferences);
}

final class WatchWalletMetadataUsecase {
  final WalletMetadataBackupRepository _repository;

  const WatchWalletMetadataUsecase(this._repository);

  Stream<void> execute() => _repository.changes;
}

final class ApplyWalletMetadataUsecase {
  final WalletMetadataBackupRepository _repository;

  const ApplyWalletMetadataUsecase(this._repository);

  @useResult
  Future<Result<void, WalletBackupFailure>> execute(
    WalletMetadataBackup metadata,
    Map<String, String> walletIds,
  ) => _repository.apply(metadata, walletIds);
}
