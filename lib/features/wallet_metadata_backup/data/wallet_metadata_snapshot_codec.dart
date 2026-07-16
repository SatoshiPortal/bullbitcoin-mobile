import 'dart:convert';

import 'package:bb_mobile/features/wallet_metadata_backup/data/mappers/wallet_metadata_snapshot_mapper.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/models/wallet_metadata_snapshot_model.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_backup_format_exception.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';
import 'package:crypto/crypto.dart';

final class WalletMetadataSnapshotCodec {
  static const _recordKeys = {
    'type',
    'version',
    'scope',
    'recordId',
    'payload',
  };
  static const _snapshotKeys = {
    'contentType',
    'envelopeVersion',
    'parentFingerprint',
    'revision',
    'createdAt',
    'recordsHash',
    'recordCount',
    'sections',
    'records',
  };
  static const _sectionKeys = {
    'type',
    'versions',
    'recordCount',
    'recordsHash',
  };

  const WalletMetadataSnapshotCodec();

  String encodeRecord(WalletMetadataRecord record) {
    final encoded = jsonEncode(
      WalletMetadataSnapshotMapper.recordToModel(record).toJson(),
    );
    _validateRecordSize(encoded);
    return encoded;
  }

  WalletMetadataRecord decodeRecord(String payload) {
    try {
      _validateRecordSize(payload);
      final record = WalletMetadataSnapshotMapper.recordToEntity(
        _parseRecordModel(_decodeObject(payload)),
      );
      if (encodeRecord(record) != payload) {
        _throwMalformed('wallet metadata record is not canonical JSON');
      }
      return record;
    } on WalletMetadataBackupFormatException {
      rethrow;
    } on FormatException catch (error) {
      _throwMalformed('wallet metadata record is malformed', cause: error);
    } on ArgumentError catch (error) {
      _throwMalformed('wallet metadata record is invalid', cause: error);
    }
  }

  String encodeSnapshot(WalletMetadataSnapshot snapshot) {
    final model = WalletMetadataSnapshotMapper.snapshotToModel(snapshot);
    for (final record in model.records) {
      _validateRecordSize(jsonEncode(record.toJson()));
    }
    final encoded = jsonEncode(model.toJson());
    _validateSnapshotSize(encoded);
    return encoded;
  }

  WalletMetadataSnapshot decodeSnapshot(String payload) {
    try {
      _validateSnapshotSize(payload);
      final json = _decodeObject(payload);
      final envelopeVersion = _int(json, 'envelopeVersion');
      _validateEnvelopeVersion(envelopeVersion);
      _expectKeys(json, _snapshotKeys, 'snapshot');
      final model = WalletMetadataSnapshotModel(
        contentType: _string(json, 'contentType'),
        envelopeVersion: envelopeVersion,
        parentFingerprint: _string(json, 'parentFingerprint'),
        revision: _int(json, 'revision'),
        createdAt: _int(json, 'createdAt'),
        recordsHash: _string(json, 'recordsHash'),
        recordCount: _int(json, 'recordCount'),
        sections: _list(json, 'sections')
            .map((value) => _parseSectionModel(_object(value, 'section')))
            .toList(growable: false),
        records: _list(json, 'records')
            .map((value) => _parseRecordModel(_object(value, 'record')))
            .toList(growable: false),
      );
      final snapshot = WalletMetadataSnapshotMapper.snapshotToEntity(model);
      validateSnapshotRecords(snapshot);
      if (encodeSnapshot(snapshot) != payload) {
        _throwMalformed('wallet metadata snapshot is not canonical JSON');
      }
      return snapshot;
    } on WalletMetadataBackupFormatException {
      rethrow;
    } on FormatException catch (error) {
      _throwMalformed('wallet metadata snapshot is malformed', cause: error);
    } on ArgumentError catch (error) {
      _throwMalformed('wallet metadata snapshot is invalid', cause: error);
    }
  }

  String canonicalRecordsJson(Iterable<WalletMetadataRecord> records) {
    return jsonEncode(
      _sortedUniqueRecords(records)
          .map(WalletMetadataSnapshotMapper.recordToModel)
          .map((record) => record.toJson())
          .toList(growable: false),
    );
  }

  String recordsHash(Iterable<WalletMetadataRecord> records) {
    return sha256
        .convert(utf8.encode(canonicalRecordsJson(records)))
        .toString();
  }

  String contentHash({
    required Iterable<WalletMetadataRecord> records,
    required Iterable<WalletMetadataSection> sections,
  }) {
    final sortedSections = sections.toList(growable: false)
      ..sort((left, right) => left.type.compareTo(right.type));
    if (sortedSections.map((section) => section.type).toSet().length !=
        sortedSections.length) {
      _throwMalformed('wallet metadata sections contain a duplicate type');
    }
    final content = jsonEncode({
      'recordsHash': recordsHash(records),
      'sections': sortedSections
          .map(WalletMetadataSnapshotMapper.sectionToModel)
          .map((section) => section.toJson())
          .toList(growable: false),
    });
    return sha256.convert(utf8.encode(content)).toString();
  }

  void validateSnapshotRecords(WalletMetadataSnapshot snapshot) {
    final canonical = _sortedUniqueRecords(snapshot.records);
    if (canonical.length != snapshot.records.length ||
        snapshot.recordCount != snapshot.records.length ||
        snapshot.recordsHash != recordsHash(snapshot.records)) {
      _throwMalformed('wallet metadata record integrity is invalid');
    }
    for (var index = 0; index < canonical.length; index++) {
      if (canonical[index].identity != snapshot.records[index].identity) {
        _throwMalformed('wallet metadata records are not canonical');
      }
    }
    final byType = <String, List<WalletMetadataRecord>>{};
    for (final record in snapshot.records) {
      byType.putIfAbsent(record.type, () => []).add(record);
    }
    for (final section in snapshot.sections) {
      final records = byType.remove(section.type) ?? const [];
      final versions = records.map((record) => record.version).toSet();
      if (section.recordCount != records.length ||
          section.recordsHash != recordsHash(records) ||
          versions.any((version) => !section.versions.contains(version))) {
        _throwMalformed('wallet metadata section integrity is invalid');
      }
    }
    if (byType.isNotEmpty) {
      _throwMalformed('wallet metadata records lack a section declaration');
    }
  }

  WalletMetadataRecordModel _parseRecordModel(Map<String, Object?> json) {
    _expectKeys(json, _recordKeys, 'record');
    return WalletMetadataRecordModel(
      type: _string(json, 'type'),
      version: _int(json, 'version'),
      scope: _object(json['scope'], 'scope'),
      recordId: _string(json, 'recordId'),
      payload: _object(json['payload'], 'payload'),
    );
  }

  WalletMetadataSectionModel _parseSectionModel(Map<String, Object?> json) {
    _expectKeys(json, _sectionKeys, 'section');
    return WalletMetadataSectionModel(
      type: _string(json, 'type'),
      versions: _list(json, 'versions')
          .map((value) => _integerValue(value, 'versions'))
          .toList(growable: false),
      recordCount: _int(json, 'recordCount'),
      recordsHash: _string(json, 'recordsHash'),
    );
  }

  List<WalletMetadataRecord> _sortedUniqueRecords(
    Iterable<WalletMetadataRecord> records,
  ) {
    final sorted = records.toList(growable: false)..sort();
    if (sorted.length > WalletMetadataBackupLimits.maxLogicalRecords) {
      _throwResourceLimit('wallet metadata record count exceeds the limit');
    }
    final identities = <String>{};
    for (final record in sorted) {
      if (!identities.add(record.identity)) {
        _throwMalformed('wallet metadata records contain a duplicate identity');
      }
      _validateRecordSize(
        jsonEncode(WalletMetadataSnapshotMapper.recordToModel(record).toJson()),
      );
    }
    return sorted;
  }

  Map<String, Object?> _decodeObject(String payload) {
    return _object(jsonDecode(payload), 'document');
  }

  void _validateEnvelopeVersion(int version) {
    if (version > WalletMetadataBackupLimits.maxSignedInt64) {
      _throwResourceLimit('wallet metadata envelope version is too large');
    }
    if (version > walletMetadataEnvelopeVersion) {
      throw WalletMetadataBackupFormatException(
        WalletMetadataBackupFormatExceptionType.unsupportedEnvelopeVersion,
        'wallet metadata envelope version is unsupported',
        envelopeVersion: version,
      );
    }
    if (version != walletMetadataEnvelopeVersion) {
      _throwMalformed('wallet metadata envelope version is invalid');
    }
  }

  void _validateRecordSize(String payload) {
    if (utf8.encode(payload).length >
        WalletMetadataBackupLimits.maxRecordCanonicalBytes) {
      _throwResourceLimit('wallet metadata record exceeds the byte limit');
    }
  }

  void _validateSnapshotSize(String payload) {
    if (utf8.encode(payload).length >
        WalletMetadataBackupLimits.maxDecryptedSnapshotBytes) {
      _throwResourceLimit('wallet metadata snapshot exceeds the byte limit');
    }
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  _throwMalformed('wallet metadata field $key must be a string');
}

int _int(Map<String, Object?> json, String key) =>
    _integerValue(json[key], key);

int _integerValue(Object? value, String description) {
  if (value is int) return value;
  _throwMalformed('wallet metadata field $description must be an integer');
}

List<Object?> _list(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is List) return List<Object?>.from(value);
  _throwMalformed('wallet metadata field $key must be a list');
}

Map<String, Object?> _object(Object? value, String description) {
  if (value is! Map) {
    _throwMalformed('wallet metadata $description must be an object');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      _throwMalformed('wallet metadata $description keys must be strings');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _expectKeys(
  Map<String, Object?> json,
  Set<String> expected,
  String description,
) {
  final keys = json.keys.toSet();
  if (keys.length != expected.length || !keys.containsAll(expected)) {
    _throwMalformed('wallet metadata $description fields are invalid');
  }
}

Never _throwMalformed(String message, {Object? cause}) {
  throw WalletMetadataBackupFormatException(
    WalletMetadataBackupFormatExceptionType.malformed,
    message,
    cause: cause,
  );
}

Never _throwResourceLimit(String message) {
  throw WalletMetadataBackupFormatException(
    WalletMetadataBackupFormatExceptionType.resourceLimit,
    message,
  );
}
