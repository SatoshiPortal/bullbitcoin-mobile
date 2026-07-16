import 'dart:convert';

import 'package:bb_mobile/features/labels/bip329_label_record.dart';
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
  const origin = "wpkh([d34db33f/84'/0'/0'])";
  const publicKey =
      '0283409659355b6d1cc3c32decd5d561abaac86c37a353b52895a5e6c196d6f448';
  const xpub =
      'xpub661MyMwAqRbcFtXgS5sYJABqqG9YLmC4Q1Rdap9gSE8NqtwybGhePY2gZ29ESFjqJoCu1Rupje8YtGqsefD265TMg7usUDFdp6W1EGMcet8';

  List<Map<String, dynamic>> lines(String jsonl) => jsonl
      .split('\n')
      .where((l) => l.trim().isNotEmpty)
      .map((l) => jsonDecode(l) as Map<String, dynamic>)
      .toList();

  group('encode — freeze projected onto spendable', () {
    test(
      'frozen-but-unlabeled coin → bare output record (spendable:false)',
      () {
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
      },
    );

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
      expect(records.firstWhere((r) => r['type'] == 'tx')['label'], 'coffee');
      expect(
        records.firstWhere((r) => r['type'] == 'output')['spendable'],
        false,
      );
    });

    test(
      'unparseable wallet origin → record without origin (still frozen)',
      () {
        final jsonl = codec.encode(
          const [],
          // A multisig-ish id we cannot reduce to a single key origin.
          frozen: const [(walletId: 'multi(...)', txId: 'abcd', vout: 1)],
        );
        final record = lines(jsonl).single;
        expect(record['spendable'], false);
        expect(record['origin'], isNull);
      },
    );

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

    test(
      'spendable:false without origin → unattributed freeze (walletId null)',
      () {
        final jsonl =
            '{"type":"output","ref":"$ref","label":"","spendable":false}';

        final decoded = codec.decode(jsonl);
        expect(decoded.labels, isEmpty);
        expect(decoded.frozen, [(walletId: null, txId: txId, vout: 0)]);
      },
    );

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

    test('output label without spendable imports as a label, not a freeze', () {
      // BIP329 marks spendable optional; a third-party file (e.g. Sparrow) that
      // labels an output without freezing it must import cleanly — under
      // bip329_labels < 2.0.0 this threw and aborted the whole import.
      final jsonl = '{"type":"output","ref":"$ref","label":"coffee"}';

      final decoded = codec.decode(jsonl);
      expect(decoded.frozen, isEmpty);
      expect(decoded.labels.single.label, 'coffee');
      expect(decoded.labels.single.type, LabelType.output);
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

  group('metadata records', () {
    test('all six types and origins round-trip without ids or freezes', () {
      final labels = [
        LabelEntity(
          id: 41,
          type: LabelType.transaction,
          reference: txId,
          label: 'Transaction',
          origin: origin,
        ),
        LabelEntity(
          id: 42,
          type: LabelType.address,
          reference: 'bc1q34aq5drpuwy3wgl9lhup9892qp6svr8ldzyy7c',
          label: 'Address',
          origin: origin,
        ),
        LabelEntity(
          id: 43,
          type: LabelType.publicKey,
          reference: publicKey,
          label: 'Public key',
          origin: origin,
        ),
        LabelEntity(
          id: 44,
          type: LabelType.input,
          reference: '$txId:1',
          label: 'Input',
          origin: origin,
        ),
        LabelEntity(
          id: 45,
          type: LabelType.output,
          reference: '$txId:2',
          label: 'Output',
          origin: origin,
        ),
        LabelEntity(
          id: 46,
          type: LabelType.extendedPublicKey,
          reference: xpub,
          label: 'Extended public key',
          origin: origin,
        ),
      ];

      final records = codec.encodeMetadataRecords(labels);

      expect(records.map((record) => record.type), [
        'tx',
        'addr',
        'pubkey',
        'input',
        'output',
        'xpub',
      ]);
      for (final record in records) {
        expect(record.origin, origin);
      }

      final decoded = codec.decodeMetadataRecords(records);
      expect(
        decoded.map((label) => label.type),
        labels.map((label) => label.type),
      );
      expect(
        decoded.map((label) => label.reference),
        labels.map((label) => label.reference),
      );
      expect(
        decoded.map((label) => label.label),
        labels.map((label) => label.label),
      );
      expect(decoded.map((label) => label.origin), everyElement(origin));
    });

    test('record identity ignores the local id and follows label plus ref', () {
      final first = LabelEntity(
        id: 1,
        type: LabelType.transaction,
        reference: txId,
        label: 'coffee',
        origin: origin,
      );
      final second = LabelEntity(
        id: 999,
        type: LabelType.transaction,
        reference: txId,
        label: 'coffee',
        origin: '[ffffffff/84h/0h/0h]',
      );

      final firstRecord = codec.encodeMetadataRecords([first]).single;
      final secondRecord = codec.encodeMetadataRecords([second]).single;

      expect(secondRecord.recordId, firstRecord.recordId);
    });

    test('the annotation entity rejects unsupported BIP329 types', () {
      expect(
        () => Bip329LabelRecord(
          type: 'unknown',
          reference: ref,
          label: 'savings',
        ),
        throwsFormatException,
      );
      expect(
        () => Bip329LabelRecord(
          type: 'tx',
          reference: 'not-a-txid',
          label: 'savings',
        ),
        throwsFormatException,
      );
    });

    test('accepts x-only public keys and rejects extended private keys', () {
      final xOnly = Bip329LabelRecord(
        type: 'pubkey',
        reference: 'a' * 64,
        label: 'Taproot key',
      );

      expect(xOnly.reference, 'a' * 64);
      expect(
        () => Bip329LabelRecord(
          type: 'xpub',
          reference:
              'xprv9s21ZrQH143K2LBWUUQRFXhucrQqBpKdRRxNVq2zBqsx8HVqFk2uYo8kmbaLLHRdqtQpUm98uKfu3vca1LqdGhUtyoFnCNkfmXRyPXLjbKb',
          label: 'Must not import',
        ),
        throwsFormatException,
      );
    });
  });
}
