import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';

final class WalletMetadataContributorInventory {
  final String recordType;
  final Set<int> supportedVersions;
  final List<WalletMetadataRecord> records;

  WalletMetadataContributorInventory({
    required this.recordType,
    required Set<int> supportedVersions,
    required List<WalletMetadataRecord> records,
  }) : supportedVersions = Set.unmodifiable(supportedVersions),
       records = List.unmodifiable(records) {
    if (recordType.trim() != recordType || recordType.isEmpty) {
      throw ArgumentError.value(recordType, 'recordType');
    }
    if (this.supportedVersions.isEmpty ||
        this.supportedVersions.any(
          (version) =>
              version <= 0 ||
              version > WalletMetadataBackupLimits.maxSignedInt64,
        )) {
      throw ArgumentError.value(supportedVersions, 'supportedVersions');
    }
    final identities = <String>{};
    for (final record in this.records) {
      if (record.type != recordType ||
          !this.supportedVersions.contains(record.version) ||
          !identities.add(record.identity)) {
        throw ArgumentError.value(records, 'records');
      }
    }
  }
}

final class WalletMetadataSnapshotInventory {
  static final _hashPattern = RegExp(r'^[0-9a-f]{64}$');

  final List<WalletMetadataRecord> records;
  final List<WalletMetadataSection> sections;
  final String recordsHash;
  final String canonicalContentHash;

  WalletMetadataSnapshotInventory({
    required List<WalletMetadataRecord> records,
    required List<WalletMetadataSection> sections,
    required this.recordsHash,
    required this.canonicalContentHash,
  }) : records = List.unmodifiable(records),
       sections = List.unmodifiable(sections) {
    if (!_hashPattern.hasMatch(recordsHash) ||
        !_hashPattern.hasMatch(canonicalContentHash)) {
      throw ArgumentError('wallet metadata inventory hashes are invalid');
    }
  }

  bool get isEmpty => records.isEmpty;
}
