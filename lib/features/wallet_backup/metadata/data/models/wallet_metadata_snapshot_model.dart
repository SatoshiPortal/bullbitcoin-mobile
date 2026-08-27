final class WalletMetadataRecordModel {
  final String type;
  final int version;
  final Map<String, Object?> scope;
  final String recordId;
  final Map<String, Object?> payload;

  WalletMetadataRecordModel({
    required this.type,
    required this.version,
    required Map<String, Object?> scope,
    required this.recordId,
    required Map<String, Object?> payload,
  }) : scope = Map.unmodifiable(scope),
       payload = Map.unmodifiable(payload);

  Map<String, Object?> toJson() => {
    'type': type,
    'version': version,
    'scope': scope,
    'recordId': recordId,
    'payload': payload,
  };
}

final class WalletMetadataSectionModel {
  final String type;
  final List<int> versions;
  final int recordCount;
  final String recordsHash;

  WalletMetadataSectionModel({
    required this.type,
    required List<int> versions,
    required this.recordCount,
    required this.recordsHash,
  }) : versions = List.unmodifiable(versions);

  Map<String, Object?> toJson() => {
    'type': type,
    'versions': versions,
    'recordCount': recordCount,
    'recordsHash': recordsHash,
  };
}

final class WalletMetadataSnapshotModel {
  final String contentType;
  final int envelopeVersion;
  final String parentFingerprint;
  final int revision;
  final int createdAt;
  final String recordsHash;
  final int recordCount;
  final List<WalletMetadataSectionModel> sections;
  final List<WalletMetadataRecordModel> records;

  WalletMetadataSnapshotModel({
    required this.contentType,
    required this.envelopeVersion,
    required this.parentFingerprint,
    required this.revision,
    required this.createdAt,
    required this.recordsHash,
    required this.recordCount,
    required List<WalletMetadataSectionModel> sections,
    required List<WalletMetadataRecordModel> records,
  }) : sections = List.unmodifiable(sections),
       records = List.unmodifiable(records);

  Map<String, Object?> toJson() => {
    'contentType': contentType,
    'envelopeVersion': envelopeVersion,
    'parentFingerprint': parentFingerprint,
    'revision': revision,
    'createdAt': createdAt,
    'recordsHash': recordsHash,
    'recordCount': recordCount,
    'sections': sections.map((value) => value.toJson()).toList(),
    'records': records.map((value) => value.toJson()).toList(),
  };
}
