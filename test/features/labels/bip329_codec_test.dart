import 'dart:convert';

import 'package:bb_mobile/features/labels/domain/label_entity.dart';
import 'package:bb_mobile/features/labels/domain/primitive/label_type.dart';
import 'package:bb_mobile/features/labels/frameworks/bip329_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final codec = Bip329LabelsCodec();

  // A real single-key Bitcoin-testnet wallet origin (wallet.id => origin).
  const walletId = 'wpkh([0f36572d/84h/1h/0h])';
  const bip329Origin = '[0f36572d/84h/1h/0h]';
  final txId = 'a' * 64;
  final ref = '$txId:0';

  List<Map<String, dynamic>> lines(String jsonl) => jsonl
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map((l) => jsonDecode(l) as Map<String, dynamic>)
      .toList();

  group('encode — freeze projected onto spendable', () {
    test('frozen-but-unlabeled coin → bare output record (spendable:false)', () {
      final jsonl = codec.encode(
        const [],
        frozen: [(walletId: walletId, txId: txId, vout: 0)],
      );

      final record = lines(jsonl).single;
      expect(record['type'], 'output');
      expect(record['ref'], ref);
      expect(record['label'], '');
      expect(record['spendable'], false);
      expect(record['origin'], bip329Origin);
    });

    test('a non-output label is emitted unchanged alongside freezes', () {
      final jsonl = codec.encode(
        [
          LabelEntity(
            id: 1,
            type: LabelType.transaction,
            reference: txId,
            label: 'coffee',
          ),
        ],
        frozen: [(walletId: walletId, txId: txId, vout: 0)],
      );

      final records = lines(jsonl);
      expect(records, hasLength(2));
      expect(
        records.firstWhere((r) => r['type'] == 'tx')['label'],
        'coffee',
      );
      expect(
        records.firstWhere((r) => r['type'] == 'output')['spendable'],
        false,
      );
    });

    test('unparseable wallet origin → record without origin (still frozen)', () {
      final jsonl = codec.encode(
        const [],
        // A multisig-ish id we cannot reduce to a single key origin.
        frozen: const [(walletId: 'multi(...)', txId: 'abcd', vout: 1)],
      );
      final record = lines(jsonl).single;
      expect(record['spendable'], false);
      expect(record['origin'], isNull);
    });

    test('origin is omitted when it would not round-trip (Liquid-testnet)', () {
      // [fp/84h/1h/0h] can't disambiguate Liquid-testnet from Bitcoin-testnet,
      // so emitting it would re-import as the wrong wallet. Emit none instead.
      final jsonl = codec.encode(
        const [],
        frozen: const [
          (walletId: 'elwpkh([0f36572d/84h/1h/0h])', txId: 'abcd', vout: 0),
        ],
      );
      final record = lines(jsonl).single;
      expect(record['spendable'], false);
      expect(record['origin'], isNull);
    });

    test('a Bitcoin-mainnet origin round-trips exactly', () {
      const mainnetId = 'wpkh([0f36572d/84h/0h/0h])';
      final jsonl = codec.encode(
        const [],
        frozen: [(walletId: mainnetId, txId: txId, vout: 0)],
      );
      expect(lines(jsonl).single['origin'], '[0f36572d/84h/0h/0h]');
      expect(codec.decode(jsonl).frozen, [
        (walletId: mainnetId, txId: txId, vout: 0),
      ]);
    });
  });

  group('decode — freeze travels as a separate channel', () {
    test('round-trips a wallet-attributed freeze (origin reconstructed)', () {
      final jsonl = codec.encode(
        const [],
        frozen: [(walletId: walletId, txId: txId, vout: 0)],
      );

      final decoded = codec.decode(jsonl);
      expect(decoded.labels, isEmpty);
      expect(decoded.frozen, [(walletId: walletId, txId: txId, vout: 0)]);
    });

    test('spendable:false without origin → unattributed freeze (walletId null)',
        () {
      final jsonl =
          '{"type":"output","ref":"$ref","label":"","spendable":false}';

      final decoded = codec.decode(jsonl);
      expect(decoded.labels, isEmpty);
      expect(decoded.frozen, [(walletId: null, txId: txId, vout: 0)]);
    });

    test('a frozen output that also has a label yields both channels', () {
      final jsonl =
          '{"type":"output","ref":"$ref","label":"savings","spendable":false}';

      final decoded = codec.decode(jsonl);
      expect(decoded.frozen, [(walletId: null, txId: txId, vout: 0)]);
      expect(decoded.labels, hasLength(1));
      expect(decoded.labels.single.label, 'savings');
      expect(decoded.labels.single.type, LabelType.output);
    });

    test('spendable:true output is a label, not a freeze', () {
      final jsonl =
          '{"type":"output","ref":"$ref","label":"rent","spendable":true}';

      final decoded = codec.decode(jsonl);
      expect(decoded.frozen, isEmpty);
      expect(decoded.labels.single.label, 'rent');
    });

    test('malformed or impossible outpoints are dropped (no freeze)', () {
      final jsonl = [
        '{"type":"output","ref":"$txId:-1","label":"","spendable":false}',
        '{"type":"output","ref":"$txId:x","label":"","spendable":false}',
        '{"type":"output","ref":"no-colon","label":"","spendable":false}',
      ].join('\n');

      final decoded = codec.decode(jsonl);
      expect(decoded.frozen, isEmpty);
      expect(decoded.labels, isEmpty);
    });
  });
}
