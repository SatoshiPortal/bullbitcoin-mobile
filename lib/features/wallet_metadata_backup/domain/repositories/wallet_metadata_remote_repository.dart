import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encrypted_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletMetadataRemoteRepository {
  @useResult
  Future<Result<WalletMetadataRemoteFetchResult, WalletMetadataBackupFailure>>
  fetch({required WalletMetadataKeyMaterial keyMaterial});

  @useResult
  Future<Result<WalletMetadataRemoteStoreReceipt, WalletMetadataBackupFailure>>
  store({
    required WalletMetadataKeyMaterial keyMaterial,
    required WalletMetadataEncryptedSnapshot snapshot,
    required int generation,
    required String? expectedEtag,
  });

  @useResult
  Future<Result<void, WalletMetadataBackupFailure>> delete({
    required WalletMetadataKeyMaterial keyMaterial,
  });
}
