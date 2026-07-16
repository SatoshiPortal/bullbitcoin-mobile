import 'package:bb_mobile/features/wallet_metadata_backup/data/models/wallet_metadata_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';

abstract final class WalletMetadataSnapshotMapper {
  static WalletMetadataRecordModel recordToModel(WalletMetadataRecord entity) {
    return WalletMetadataRecordModel(
      type: entity.type,
      version: entity.version,
      scope: entity.scope,
      recordId: entity.recordId,
      payload: entity.payload,
    );
  }

  static WalletMetadataRecord recordToEntity(WalletMetadataRecordModel model) {
    return WalletMetadataRecord(
      type: model.type,
      version: model.version,
      scope: model.scope,
      recordId: model.recordId,
      payload: model.payload,
    );
  }

  static WalletMetadataSectionModel sectionToModel(
    WalletMetadataSection entity,
  ) {
    return WalletMetadataSectionModel(
      type: entity.type,
      versions: entity.versions,
      recordCount: entity.recordCount,
      recordsHash: entity.recordsHash,
    );
  }

  static WalletMetadataSection sectionToEntity(
    WalletMetadataSectionModel model,
  ) {
    return WalletMetadataSection(
      type: model.type,
      versions: model.versions,
      recordCount: model.recordCount,
      recordsHash: model.recordsHash,
    );
  }

  static WalletMetadataSnapshotModel snapshotToModel(
    WalletMetadataSnapshot entity,
  ) {
    return WalletMetadataSnapshotModel(
      contentType: entity.contentType,
      envelopeVersion: entity.envelopeVersion,
      parentFingerprint: entity.parentFingerprint,
      revision: entity.revision,
      createdAt: entity.createdAt,
      recordsHash: entity.recordsHash,
      recordCount: entity.recordCount,
      sections: entity.sections.map(sectionToModel).toList(growable: false),
      records: entity.records.map(recordToModel).toList(growable: false),
    );
  }

  static WalletMetadataSnapshot snapshotToEntity(
    WalletMetadataSnapshotModel model,
  ) {
    return WalletMetadataSnapshot(
      contentType: model.contentType,
      envelopeVersion: model.envelopeVersion,
      parentFingerprint: model.parentFingerprint,
      revision: model.revision,
      createdAt: model.createdAt,
      recordsHash: model.recordsHash,
      recordCount: model.recordCount,
      sections: model.sections.map(sectionToEntity).toList(growable: false),
      records: model.records.map(recordToEntity).toList(growable: false),
    );
  }
}
