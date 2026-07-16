import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encrypted_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

abstract interface class WalletMetadataSnapshotCryptor {
  @useResult
  Result<WalletMetadataEncryptedSnapshot, WalletMetadataBackupFailure> build({
    required WalletMetadataKeyMaterial keyMaterial,
    required int revision,
    required int createdAt,
    required List<WalletMetadataRecord> records,
    required List<WalletMetadataSection> sections,
  });

  @useResult
  Result<WalletMetadataSnapshot, WalletMetadataBackupFailure> decrypt({
    required WalletMetadataKeyMaterial keyMaterial,
    required String ciphertext,
  });
}
