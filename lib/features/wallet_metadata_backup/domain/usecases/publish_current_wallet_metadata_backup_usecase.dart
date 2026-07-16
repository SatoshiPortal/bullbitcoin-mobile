import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_publish_outcome.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/publish_wallet_metadata_backup_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_key_material_port.dart';
import 'package:meta/meta.dart';

final class PublishCurrentWalletMetadataBackupUsecase {
  final WalletMetadataBackupStateRepository _stateRepository;
  final WalletMetadataKeyMaterialPort _keyMaterialPort;
  final PublishWalletMetadataBackupUsecase _publish;

  const PublishCurrentWalletMetadataBackupUsecase({
    required this._stateRepository,
    required WalletMetadataKeyMaterialPort keyMaterialPort,
    required this._publish,
    // ignore: prefer_initializing_formals
  }) : _keyMaterialPort = keyMaterialPort;

  @useResult
  Future<Result<WalletMetadataPublishOutcome, WalletMetadataBackupFailure>>
  execute() async {
    final stateResult = await _stateRepository.fetch();
    switch (stateResult) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value) when !value.canAttemptStore:
        return const Ok(
          WalletMetadataPublishOutcome(
            status: WalletMetadataPublishStatus.notReady,
          ),
        );
      case Ok():
        break;
    }

    final keyMaterialResult = await _keyMaterialPort.deriveLocal();
    switch (keyMaterialResult) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return _publish.execute(keyMaterial: value);
    }
  }
}
