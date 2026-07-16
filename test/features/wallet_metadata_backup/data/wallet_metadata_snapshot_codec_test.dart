import 'dart:convert';

import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_snapshot.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = WalletMetadataSnapshotCodec();

  test('round-trips one canonical snapshot and rejects non-canonical JSON', () {
    final record = _label(1);
    final snapshot = _snapshot([record]);
    final encoded = codec.encodeSnapshot(snapshot);

    expect(codec.encodeSnapshot(codec.decodeSnapshot(encoded)), encoded);
    expect(() => codec.decodeSnapshot(' ${encoded.trim()}'), throwsA(anything));
  });

  test('representative 1000-label snapshot stays below 2 MiB', () {
    final records = List.generate(1000, _label);
    final encoded = codec.encodeSnapshot(_snapshot(records));
    final encodedBytes = utf8.encode(encoded).length;

    expect(encodedBytes, lessThan(512 * 1024));
    expect(
      encodedBytes,
      lessThan(WalletMetadataBackupLimits.maxDecryptedSnapshotBytes),
    );
    expect(codec.decodeSnapshot(encoded).recordCount, 1000);
  });
}

WalletMetadataSnapshot _snapshot(List<WalletMetadataRecord> records) {
  const codec = WalletMetadataSnapshotCodec();
  final section = WalletMetadataSection(
    type: 'bip329.label',
    versions: const [1],
    recordCount: records.length,
    recordsHash: codec.recordsHash(records),
  );
  return WalletMetadataSnapshot(
    parentFingerprint: '627ef3a6',
    revision: 1,
    createdAt: 10,
    recordsHash: codec.recordsHash(records),
    recordCount: records.length,
    sections: [section],
    records: records,
  );
}

WalletMetadataRecord _label(int index) {
  return WalletMetadataRecord(
    type: 'bip329.label',
    version: 1,
    scope: const {'network': 'bitcoin'},
    recordId: index.toRadixString(16).padLeft(64, '0'),
    payload: {
      'type': 'tx',
      'ref': index.toRadixString(16).padLeft(64, '0'),
      'label': 'Representative transaction label $index',
      'origin': 'manual',
      'spendable': null,
    },
  );
}
