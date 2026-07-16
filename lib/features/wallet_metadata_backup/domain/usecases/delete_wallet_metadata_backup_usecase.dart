import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_backup_state_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_remote_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_key_material_port.dart';
import 'package:meta/meta.dart';

final class DeleteWalletMetadataBackupUsecase {
  final WalletMetadataBackupStateRepository _stateRepository;
  final WalletMetadataRemoteRepository _remoteRepository;
  final WalletMetadataKeyMaterialPort _keyMaterialPort;

  const DeleteWalletMetadataBackupUsecase({
    required this._stateRepository,
    required this._remoteRepository,
    required WalletMetadataKeyMaterialPort keyMaterialPort,
    // ignore: prefer_initializing_formals
  }) : _keyMaterialPort = keyMaterialPort;

  @useResult
  Future<Result<void, WalletMetadataBackupFailure>> execute() async {
    final stateResult = await _stateRepository.fetch();
    switch (stateResult) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value) when value.enabled:
        return const Err(WalletMetadataBackupDeleteRequiresDisabledFailure());
      case Ok():
        break;
    }
    final keyMaterial = await _keyMaterialPort.deriveLocal();
    switch (keyMaterial) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final value):
        final deleted = await _remoteRepository.delete(keyMaterial: value);
        if (deleted case Err(:final failure)) return Err(failure);
    }
    final cleared = await _stateRepository.update(
      (current) => current.clearRemoteCheckpoint(),
    );
    return switch (cleared) {
      Ok() => const Ok(null),
      Err(:final failure) => Err(failure),
    };
  }
}
