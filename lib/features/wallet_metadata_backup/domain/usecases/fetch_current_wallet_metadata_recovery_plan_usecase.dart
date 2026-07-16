import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_recovery_plan.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/usecases/fetch_wallet_metadata_recovery_plan_usecase.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_key_material_port.dart';
import 'package:meta/meta.dart';

final class FetchCurrentWalletMetadataRecoveryPlanUsecase {
  final WalletMetadataKeyMaterialPort _keyMaterial;
  final FetchWalletMetadataRecoveryPlanUsecase _fetch;

  const FetchCurrentWalletMetadataRecoveryPlanUsecase({
    required WalletMetadataKeyMaterialPort keyMaterial,
    required FetchWalletMetadataRecoveryPlanUsecase fetch,
    // ignore: prefer_initializing_formals
  }) : _keyMaterial = keyMaterial,
       // ignore: prefer_initializing_formals
       _fetch = fetch;

  @useResult
  Future<Result<WalletMetadataRecoveryResult, WalletMetadataBackupFailure>>
  execute() async {
    final keyMaterial = await _keyMaterial.deriveLocal();
    return switch (keyMaterial) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _fetch.execute(keyMaterial: value),
    };
  }
}
