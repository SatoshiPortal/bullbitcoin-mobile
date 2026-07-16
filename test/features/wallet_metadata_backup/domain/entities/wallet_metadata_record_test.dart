import 'package:bb_mobile/features/wallet_metadata_backup/data/wallet_metadata_snapshot_codec.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/entities/wallet_metadata_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const codec = WalletMetadataSnapshotCodec();

  test('canonicalizes nested object keys without changing array order', () {
    final record = WalletMetadataRecord(
      type: 'future.record',
      version: 3,
      scope: const {'z': 1, 'a': 2},
      recordId: 'record-1',
      payload: const {
        'z': [3, 2, 1],
        'a': {'second': true, 'first': false},
      },
    );

    expect(
      codec.encodeRecord(record),
      '{"type":"future.record","version":3,"scope":{"a":2,"z":1},'
      '"recordId":"record-1","payload":{"a":{"first":false,'
      '"second":true},"z":[3,2,1]}}',
    );
  });

  test('deep freezes scope and payload', () {
    final record = WalletMetadataRecord(
      type: 'future.record',
      version: 1,
      scope: const {
        'nested': {'key': 'value'},
      },
      recordId: 'record-1',
      payload: const {
        'items': [1, 2],
      },
    );

    expect(() => record.scope['other'] = true, throwsUnsupportedError);
    expect(
      () => (record.scope['nested']! as Map<String, Object?>)['key'] = 'new',
      throwsUnsupportedError,
    );
    expect(
      () => (record.payload['items']! as List<Object?>).add(3),
      throwsUnsupportedError,
    );
  });

  test('orders records by type, version, scope, then record id', () {
    WalletMetadataRecord record({
      required String type,
      required int version,
      required Map<String, Object?> scope,
      required String id,
    }) {
      return WalletMetadataRecord(
        type: type,
        version: version,
        scope: scope,
        recordId: id,
        payload: const {},
      );
    }

    final records = [
      record(type: 'b', version: 1, scope: const {}, id: '1'),
      record(type: 'a', version: 2, scope: const {}, id: '1'),
      record(type: 'a', version: 1, scope: const {'b': 1}, id: '1'),
      record(type: 'a', version: 1, scope: const {'a': 1}, id: '2'),
      record(type: 'a', version: 1, scope: const {'a': 1}, id: '1'),
    ]..sort();

    expect(records.map((record) => record.identity), [
      '["a",1,{"a":1},"1"]',
      '["a",1,{"a":1},"2"]',
      '["a",1,{"b":1},"1"]',
      '["a",2,{},"1"]',
      '["b",1,{},"1"]',
    ]);
  });

  test('rejects non-integer JSON numbers and excessive nesting', () {
    expect(
      () => WalletMetadataRecord(
        type: 'future.record',
        version: 1,
        scope: const {},
        recordId: 'record-1',
        payload: const {'fraction': 1.5},
      ),
      throwsArgumentError,
    );

    Object? nested = 'leaf';
    for (var i = 0; i < 34; i++) {
      nested = <String, Object?>{'nested': nested};
    }
    expect(
      () => WalletMetadataRecord(
        type: 'future.record',
        version: 1,
        scope: const {},
        recordId: 'record-1',
        payload: nested! as Map<String, Object?>,
      ),
      throwsArgumentError,
    );
  });
}
