import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_authenticated_cipher.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_backup_format_exception.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_key_deriver.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_encrypted_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_key_material.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_snapshot_cryptor.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

final class WalletMetadataSnapshotCryptorImpl
    implements WalletMetadataSnapshotCryptor {
  final WalletMetadataSnapshotCodec codec;
  final WalletMetadataKeyDeriver keyDeriver;
  final WalletMetadataAuthenticatedCipher cipher;

  const WalletMetadataSnapshotCryptorImpl({
    this.codec = const WalletMetadataSnapshotCodec(),
    this.keyDeriver = const WalletMetadataKeyDeriver(),
    this.cipher = const WalletMetadataAuthenticatedCipher(),
  });

  @override
  @useResult
  Result<WalletMetadataEncryptedSnapshot, WalletMetadataBackupFailure> build({
    required WalletMetadataKeyMaterial keyMaterial,
    required int revision,
    required int createdAt,
    required List<WalletMetadataRecord> records,
    required List<WalletMetadataSection> sections,
  }) {
    try {
      final sortedRecords = List<WalletMetadataRecord>.of(records)..sort();
      final snapshot = WalletMetadataSnapshot(
        parentFingerprint: keyMaterial.parentFingerprint,
        revision: revision,
        createdAt: createdAt,
        recordsHash: codec.recordsHash(sortedRecords),
        recordCount: sortedRecords.length,
        sections: sections,
        records: sortedRecords,
      );
      codec.validateSnapshotRecords(snapshot);
      final key = keyDeriver.deriveEncryptionKey(
        xprvBase58: keyMaterial.xprvBase58,
        expectedParentFingerprint: keyMaterial.parentFingerprint,
      );
      final ciphertext = cipher.encrypt(
        plaintext: codec.encodeSnapshot(snapshot),
        key: key,
      );
      return Ok(
        WalletMetadataEncryptedSnapshot(
          plaintext: snapshot,
          ciphertext: ciphertext,
        ),
      );
    } on WalletMetadataKeyDerivationException {
      return const Err(WalletMetadataBackupKeyFailure());
    } on WalletMetadataBackupFormatException catch (error) {
      return error.type == WalletMetadataBackupFormatExceptionType.resourceLimit
          ? const Err(WalletMetadataBackupResourceLimitFailure())
          : const Err(WalletMetadataBackupEncodingFailure());
    } on WalletMetadataCipherException {
      return const Err(WalletMetadataBackupEncodingFailure());
    } on ArgumentError {
      return const Err(WalletMetadataBackupEncodingFailure());
    }
  }

  @override
  @useResult
  Result<WalletMetadataSnapshot, WalletMetadataBackupFailure> decrypt({
    required WalletMetadataKeyMaterial keyMaterial,
    required String ciphertext,
  }) {
    try {
      final key = keyDeriver.deriveEncryptionKey(
        xprvBase58: keyMaterial.xprvBase58,
        expectedParentFingerprint: keyMaterial.parentFingerprint,
      );
      final plaintext = cipher.decrypt(ciphertext: ciphertext, key: key);
      final snapshot = codec.decodeSnapshot(plaintext);
      if (snapshot.parentFingerprint != keyMaterial.parentFingerprint) {
        return const Err(WalletMetadataBackupKeyFailure());
      }
      return Ok(snapshot);
    } on WalletMetadataKeyDerivationException {
      return const Err(WalletMetadataBackupKeyFailure());
    } on WalletMetadataBackupFormatException catch (error) {
      if (error.type ==
          WalletMetadataBackupFormatExceptionType.unsupportedEnvelopeVersion) {
        return Err(
          WalletMetadataBackupUpdateRequiredFailure(
            envelopeVersion: error.envelopeVersion,
          ),
        );
      }
      return error.type == WalletMetadataBackupFormatExceptionType.resourceLimit
          ? const Err(WalletMetadataBackupResourceLimitFailure())
          : const Err(WalletMetadataBackupEncodingFailure());
    } on WalletMetadataCipherException {
      return const Err(WalletMetadataBackupEncodingFailure());
    } on ArgumentError {
      return const Err(WalletMetadataBackupEncodingFailure());
    }
  }
}
