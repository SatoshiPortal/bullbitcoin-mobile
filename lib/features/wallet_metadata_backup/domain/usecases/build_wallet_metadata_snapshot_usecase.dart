import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encrypted_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_snapshot_cryptor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

final class BuildWalletMetadataSnapshotUsecase {
  final WalletMetadataSnapshotCryptor _repository;

  const BuildWalletMetadataSnapshotUsecase(this._repository);

  @useResult
  Result<WalletMetadataEncryptedSnapshot, WalletMetadataBackupFailure> execute({
    required WalletMetadataKeyMaterial keyMaterial,
    required int revision,
    required int createdAt,
    required List<WalletMetadataRecord> records,
    required List<WalletMetadataSection> sections,
  }) {
    return _repository.build(
      keyMaterial: keyMaterial,
      revision: revision,
      createdAt: createdAt,
      records: records,
      sections: sections,
    );
  }
}
