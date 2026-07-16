import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_backup_state.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

final class GetWalletMetadataBackupStateUsecase {
  final WalletMetadataBackupStateRepository _repository;

  const GetWalletMetadataBackupStateUsecase(this._repository);

  @useResult
  Future<Result<WalletMetadataBackupState, WalletMetadataBackupFailure>>
  execute() {
    return _repository.fetch();
  }
}
