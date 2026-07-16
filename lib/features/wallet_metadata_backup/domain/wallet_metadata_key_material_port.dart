import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletMetadataKeyMaterialPort {
  @useResult
  Future<Result<WalletMetadataKeyMaterial, WalletMetadataBackupFailure>>
  deriveLocal();
}
