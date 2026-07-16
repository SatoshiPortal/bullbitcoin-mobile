import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_backup_format_exception.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_inventory.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_remote_head.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/repositories/wallet_metadata_snapshot_composition_repository.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_failure.dart';
import 'package:meta/meta.dart';

final class WalletMetadataSnapshotCompositionRepositoryImpl
    implements WalletMetadataSnapshotCompositionRepository {
  final WalletMetadataSnapshotCodec _codec;

  const WalletMetadataSnapshotCompositionRepositoryImpl({
    this._codec = const WalletMetadataSnapshotCodec(),
  });

  @override
  @useResult
  Result<WalletMetadataSnapshotInventory, WalletMetadataBackupFailure> compose({
    required List<WalletMetadataContributorInventory> contributors,
    required WalletMetadataRemoteHead? remoteHead,
  }) {
    try {
      final contributorsByType = <String, WalletMetadataContributorInventory>{};
      for (final contributor in contributors) {
        if (contributorsByType.containsKey(contributor.recordType)) {
          throw const _WalletMetadataCompositionException();
        }
        contributorsByType[contributor.recordType] = contributor;
      }

      final records = <WalletMetadataRecord>[
        ...contributors.expand((contributor) => contributor.records),
        ...?remoteHead?.records.where((record) {
          final contributor = contributorsByType[record.type];
          return contributor == null ||
              !contributor.supportedVersions.contains(record.version);
        }),
      ]..sort();
      _codec.canonicalRecordsJson(records);

      final remoteSectionsByType = {
        for (final section in remoteHead?.snapshot.sections ?? const [])
          section.type: section,
      };
      final sectionTypes = <String>{
        ...contributorsByType.keys,
        ...remoteSectionsByType.keys,
        ...records.map((record) => record.type),
      }.toList(growable: false)..sort();
      final sections = sectionTypes
          .map((type) {
            final contributor = contributorsByType[type];
            final versions = <int>{...?contributor?.supportedVersions};
            final remoteSection = remoteSectionsByType[type];
            if (remoteSection != null) {
              versions.addAll(
                remoteSection.versions.where(
                  (version) =>
                      contributor == null ||
                      !contributor.supportedVersions.contains(version),
                ),
              );
            }
            final sectionRecords = records
                .where((record) => record.type == type)
                .toList(growable: false);
            versions.addAll(sectionRecords.map((record) => record.version));
            return WalletMetadataSection(
              type: type,
              versions: versions.toList(growable: false),
              recordCount: sectionRecords.length,
              recordsHash: _codec.recordsHash(sectionRecords),
            );
          })
          .toList(growable: false);

      return Ok(
        WalletMetadataSnapshotInventory(
          records: records,
          sections: sections,
          recordsHash: _codec.recordsHash(records),
          canonicalContentHash: _codec.contentHash(
            records: records,
            sections: sections,
          ),
        ),
      );
    } on WalletMetadataBackupFormatException {
      return const Err(WalletMetadataBackupEncodingFailure());
    } on _WalletMetadataCompositionException {
      return const Err(WalletMetadataBackupEncodingFailure());
    }
  }
}

final class _WalletMetadataCompositionException implements Exception {
  const _WalletMetadataCompositionException();
}
