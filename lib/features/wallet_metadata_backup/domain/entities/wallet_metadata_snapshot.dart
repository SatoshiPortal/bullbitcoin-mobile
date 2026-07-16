import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_json.dart';

const int walletMetadataEnvelopeVersion = 1;
const String walletMetadataContentType = 'bullbitcoin.wallet_metadata';

final RegExp _fingerprintPattern = RegExp(r'^[0-9a-f]{8}$');
final RegExp _hashPattern = RegExp(r'^[0-9a-f]{64}$');

final class WalletMetadataSection {
  final String type;
  final List<int> versions;
  final int recordCount;
  final String recordsHash;

  factory WalletMetadataSection({
    required String type,
    required List<int> versions,
    required int recordCount,
    required String recordsHash,
  }) {
    if (versions.isEmpty) {
      throw ArgumentError.value(versions, 'versions', 'must not be empty');
    }
    final sortedVersions = List<int>.of(versions)..sort();
    if (sortedVersions.any(
          (version) =>
              version <= 0 ||
              version > WalletMetadataBackupLimits.maxSignedInt64,
        ) ||
        sortedVersions.toSet().length != sortedVersions.length) {
      throw ArgumentError.value(versions, 'versions');
    }
    _validateRecordCount(recordCount);
    _validateHash(recordsHash, 'recordsHash');
    return WalletMetadataSection._(
      type: walletMetadataValidateString(type, name: 'type', allowEmpty: false),
      versions: List.unmodifiable(sortedVersions),
      recordCount: recordCount,
      recordsHash: recordsHash,
    );
  }

  const WalletMetadataSection._({
    required this.type,
    required this.versions,
    required this.recordCount,
    required this.recordsHash,
  });
}

final class WalletMetadataSnapshot {
  final String contentType;
  final int envelopeVersion;
  final String parentFingerprint;
  final int revision;
  final int createdAt;
  final String recordsHash;
  final int recordCount;
  final List<WalletMetadataSection> sections;
  final List<WalletMetadataRecord> records;

  factory WalletMetadataSnapshot({
    String contentType = walletMetadataContentType,
    int envelopeVersion = walletMetadataEnvelopeVersion,
    required String parentFingerprint,
    required int revision,
    required int createdAt,
    required String recordsHash,
    required int recordCount,
    required List<WalletMetadataSection> sections,
    required List<WalletMetadataRecord> records,
  }) {
    if (contentType != walletMetadataContentType ||
        envelopeVersion != walletMetadataEnvelopeVersion) {
      throw ArgumentError('wallet metadata envelope header is invalid');
    }
    if (!_fingerprintPattern.hasMatch(parentFingerprint)) {
      throw ArgumentError.value(parentFingerprint, 'parentFingerprint');
    }
    _validateNonNegativeInt64(revision, 'revision');
    _validateNonNegativeInt64(createdAt, 'createdAt');
    _validateHash(recordsHash, 'recordsHash');
    _validateRecordCount(recordCount);

    final sortedSections = List<WalletMetadataSection>.of(sections)
      ..sort((left, right) => left.type.compareTo(right.type));
    final sortedRecords = List<WalletMetadataRecord>.of(records)..sort();
    if (sortedSections.map((value) => value.type).toSet().length !=
            sortedSections.length ||
        sortedRecords.map((value) => value.identity).toSet().length !=
            sortedRecords.length ||
        sortedRecords.length != recordCount ||
        sortedSections.fold<int>(
              0,
              (count, section) => count + section.recordCount,
            ) !=
            recordCount) {
      throw ArgumentError('wallet metadata snapshot index is invalid');
    }
    return WalletMetadataSnapshot._(
      contentType: contentType,
      envelopeVersion: envelopeVersion,
      parentFingerprint: parentFingerprint,
      revision: revision,
      createdAt: createdAt,
      recordsHash: recordsHash,
      recordCount: recordCount,
      sections: List.unmodifiable(sortedSections),
      records: List.unmodifiable(sortedRecords),
    );
  }

  const WalletMetadataSnapshot._({
    required this.contentType,
    required this.envelopeVersion,
    required this.parentFingerprint,
    required this.revision,
    required this.createdAt,
    required this.recordsHash,
    required this.recordCount,
    required this.sections,
    required this.records,
  });
}

void _validateHash(String value, String name) {
  if (!_hashPattern.hasMatch(value)) {
    throw ArgumentError.value(value, name, 'must be lowercase 32-byte hex');
  }
}

void _validateRecordCount(int value) {
  if (value < 0 || value > WalletMetadataBackupLimits.maxLogicalRecords) {
    throw ArgumentError.value(value, 'recordCount');
  }
}

void _validateNonNegativeInt64(int value, String name) {
  if (value < 0 || value > WalletMetadataBackupLimits.maxSignedInt64) {
    throw ArgumentError.value(value, name);
  }
}
