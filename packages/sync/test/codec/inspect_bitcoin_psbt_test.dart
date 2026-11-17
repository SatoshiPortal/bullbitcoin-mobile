import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/src/data/codec/psbt_unsigned_transaction.dart';
import 'package:sync/sync.dart';

const _publicKey =
    '0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798';
const _witnessScript = [0, 20, ..._hash];
const _hash = [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1];
const _money = 21000000 * 100000000;

List<int> _hex(String hex) => [
  for (var index = 0; index < hex.length; index += 2)
    int.parse(hex.substring(index, index + 2), radix: 16),
];

List<int> _size(int value) {
  if (value < 0xfd) return [value];
  final bytes = ByteData(value <= 0xffff ? 2 : 4);
  if (value <= 0xffff) {
    bytes.setUint16(0, value, Endian.little);
    return [0xfd, ...bytes.buffer.asUint8List()];
  }
  bytes.setUint32(0, value, Endian.little);
  return [0xfe, ...bytes.buffer.asUint8List()];
}

List<int> _u64(int value) =>
    (ByteData(8)..setUint64(0, value, Endian.little)).buffer.asUint8List();

List<int> _output(int value, List<int> script) => [
  ..._u64(value),
  ..._size(script.length),
  ...script,
];

List<int> _tx(List<Outpoint> inputs, List<List<int>> outputs) => [
  2,
  0,
  0,
  0,
  ..._size(inputs.length),
  for (final input in inputs) ...[
    ..._hex(input.txId).reversed,
    ...(ByteData(
      4,
    )..setUint32(0, input.vout, Endian.little)).buffer.asUint8List(),
    0,
    0xfd,
    0xff,
    0xff,
    0xff,
  ],
  ..._size(outputs.length),
  for (final output in outputs) ...output,
  0,
  0,
  0,
  0,
];

List<int> _entry(List<int> key, List<int> value) => [
  ..._size(key.length),
  ...key,
  ..._size(value.length),
  ...value,
];

List<int> _witness({int value = 50000, List<int> script = _witnessScript}) =>
    _entry([1], _output(value, script));

String _psbt({
  List<Outpoint>? inputs,
  List<List<int>>? maps,
  List<List<int>>? outputs,
}) {
  final selected = inputs ?? [(txId: '11' * 32, vout: 0)];
  final payees =
      outputs ??
      [
        _output(10000, [0x51]),
      ];
  return base64Encode([
    0x70,
    0x73,
    0x62,
    0x74,
    0xff,
    ..._entry([0], _tx(selected, payees)),
    0,
    for (final map in maps ?? [for (final _ in selected) _witness()]) ...[
      ...map,
      0,
    ],
    for (final _ in payees) 0,
  ]);
}

BitcoinPsbtFacts _ok(String encoded) => switch (inspectBitcoinPsbt(encoded)) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Unexpected ${failure.logCode}'),
};

void _refused(String encoded) {
  expect(
    inspectBitcoinPsbt(encoded),
    isA<Err<BitcoinPsbtFacts, SyncFailure>>(),
  );
  expect(
    (inspectBitcoinPsbt(encoded) as Err<BitcoinPsbtFacts, SyncFailure>).failure,
    isA<SyncInvalidTransactionFailure>(),
  );
}

void main() {
  test('witness prevout, fee, unsigned identity and ordered outputs', () {
    final facts = _ok(_psbt());
    expect(facts.unsignedTxid, decodeBitcoinPsbt(_psbt()).txid);
    expect(facts.feeSat, 40000);
    expect(facts.inputs.single.outpoint, (txId: '11' * 32, vout: 0));
    expect(facts.inputs.single.prevoutValueSat, 50000);
    expect(facts.inputs.single.prevoutScriptPubkey, _witnessScript);
    expect(facts.outputs.single.valueSat, 10000);
    expect(facts.outputs.single.scriptPubkey, [0x51]);
    expect(facts.finalTransaction, isNull);
    expect(facts.inputs.single.hasFinalFields, isFalse);
    expect(facts.inputs.single.hasFinalWitness, isFalse);
    expect(facts.inputs.single.hasPartialSignatures, isFalse);
  });

  test('nonwitness prevout and matching dual evidence resolve identically', () {
    final parent = _tx(
      [(txId: '22' * 32, vout: 0)],
      [_output(50000, _witnessScript)],
    );
    final outpoint = (txId: decodeBitcoinTransaction(parent).txid, vout: 0);
    for (final map in [
      _entry([0], parent),
      [
        ..._entry([0], parent),
        ..._witness(),
      ],
    ]) {
      final facts = _ok(_psbt(inputs: [outpoint], maps: [map]));
      expect(facts.feeSat, 40000);
      expect(facts.inputs.single.prevoutValueSat, 50000);
      expect(facts.inputs.single.prevoutScriptPubkey, _witnessScript);
    }
  });

  test('missing, wrong txid/vout, contradictory value/script refuse', () {
    final parent = _tx(
      [(txId: '22' * 32, vout: 0)],
      [_output(50000, _witnessScript)],
    );
    final txid = decodeBitcoinTransaction(parent).txid;
    _refused(_psbt(maps: [[]]));
    _refused(
      _psbt(
        maps: [
          _entry([0], parent),
        ],
      ),
    );
    _refused(
      _psbt(
        inputs: [(txId: txid, vout: 1)],
        maps: [
          _entry([0], parent),
        ],
      ),
    );
    for (final witness in [
      _witness(value: 50001),
      _witness(script: [0x51]),
    ]) {
      _refused(
        _psbt(
          inputs: [(txId: txid, vout: 0)],
          maps: [
            [
              ..._entry([0], parent),
              ...witness,
            ],
          ],
        ),
      );
    }
  });

  test('preserves multiple input/output order and partial finalisation', () {
    final points = [(txId: '11' * 32, vout: 2), (txId: '22' * 32, vout: 1)];
    final facts = _ok(
      _psbt(
        inputs: points,
        maps: [
          [
            ..._witness(),
            ..._entry([8], [1, 1, 7]),
          ],
          _witness(value: 60000),
        ],
        outputs: [
          _output(10000, [0x51]),
          _output(20000, [0x52]),
        ],
      ),
    );
    expect(facts.inputs.map((input) => input.outpoint), points);
    expect(facts.inputs.map((input) => input.prevoutValueSat), [50000, 60000]);
    expect(facts.outputs.map((output) => output.valueSat), [10000, 20000]);
    expect(facts.feeSat, 80000);
    expect(facts.inputs.first.hasFinalFields, isTrue);
    expect(facts.inputs.last.hasFinalFields, isFalse);
    expect(facts.finalTransaction, isNull);
  });

  test(
    'partial ECDSA and taproot signatures are visible without finalisation',
    () {
      final partial = _entry(
        [2, ..._hex(_publicKey)],
        [
          0x30,
          0x44,
          2,
          0x20,
          ...List.filled(32, 1),
          2,
          0x20,
          ...List.filled(32, 2),
          1,
        ],
      );
      final tapKey = _entry([0x13], List.filled(64, 1));
      final tapScript = _entry([
        0x14,
        ..._hex(_publicKey.substring(2)),
        ...List.filled(32, 0),
      ], List.filled(64, 2));
      final maps = [partial, tapKey, tapScript];
      for (var index = 0; index < maps.length; index++) {
        final facts = _ok(
          _psbt(
            maps: [
              [..._witness(), ...maps[index]],
            ],
          ),
        );
        final input = facts.inputs.single;
        expect(input.hasPartialSignatures, index == 0);
        expect(input.hasTaprootKeySignature, index == 1);
        expect(input.hasTaprootScriptSignatures, index == 2);
        expect(input.hasFinalFields, isFalse);
        expect(facts.finalTransaction, isNull);
      }
    },
  );

  test(
    'empty versus absent final fields and nonempty witness stack stay distinct',
    () {
      for (final (key, bytes) in [
        (7, <int>[]),
        (8, [0]),
        (8, [1, 0]),
      ]) {
        final facts = _ok(
          _psbt(
            maps: [
              [
                ..._witness(),
                ..._entry([key], bytes),
              ],
            ],
          ),
        );
        final input = facts.inputs.single;
        expect(input.hasFinalFields, isTrue);
        expect(input.hasFinalWitness, key == 8 && bytes.length == 2);
        expect(facts.finalTransaction, isNotNull);
        if (key == 7) {
          expect(input.finalScriptSig, isEmpty);
          expect(input.finalScriptWitness, isNull);
        } else {
          expect(input.finalScriptSig, isNull);
          expect(
            input.finalScriptWitness,
            bytes.length == 1 ? isEmpty : [<int>[]],
          );
        }
      }
    },
  );

  test('structural extraction retains exact witness bytes, which txid does not bind', () {
    final first = _ok(
      _psbt(
        maps: [
          [
            ..._witness(),
            ..._entry([8], [1, 1, 7]),
          ],
        ],
      ),
    );
    final second = _ok(
      _psbt(
        maps: [
          [
            ..._witness(),
            ..._entry([8], [1, 1, 8]),
          ],
        ],
      ),
    );
    final a = first.finalTransaction;
    final b = second.finalTransaction;
    if (a == null || b == null) fail('Expected structural final transactions');
    expect(a.txid, b.txid);
    expect(a.txid, first.unsignedTxid);
    expect(a.bytes, isNot(equals(b.bytes)));
    expect(decodeBitcoinTransaction(a.bytes).txid, a.txid);
    expect(first.inputs.single.finalScriptWitness, [
      [7],
    ]);
    // These dummy witness items are not signatures; success asserts no script validity.
  });

  test(
    'legacy final scriptSig changes extracted txid but never unsigned identity',
    () {
      final original = _ok(_psbt());
      final signed = _ok(
        _psbt(
          maps: [
            [
              ..._witness(script: [0x51]),
              ..._entry([7], [1, 1]),
            ],
          ],
        ),
      );
      expect(signed.unsignedTxid, original.unsignedTxid);
      expect(signed.finalTransaction?.txid, isNot(signed.unsignedTxid));
      expect(signed.finalTransaction?.inputDetails.single.scriptSig, [1, 1]);
    },
  );

  test('amount and total bounds, negative fees and checked extraction failures refuse', () {
    _refused(_psbt(maps: [_witness(value: _money + 1)]));
    _refused(_psbt(maps: [_witness(value: 1)]));
    _refused(
      _psbt(
        outputs: [
          _output(_money + 1, [0x51]),
        ],
      ),
    );
    _refused(
      _psbt(
        inputs: [(txId: '11' * 32, vout: 0), (txId: '22' * 32, vout: 0)],
        maps: [
          _witness(value: _money),
          _witness(value: 1),
        ],
      ),
    );
    // Individually valid amounts, but native checked extraction refuses the absurd fee rate.
    _refused(
      _psbt(
        maps: [
          [
            ..._witness(value: _money),
            ..._entry([8], [1, 1, 1]),
          ],
        ],
      ),
    );
  });

  test('published bytes and every witness list level are immutable defensive copies', () {
    final witness = <List<int>>[
      [7],
    ];
    final script = <int>[0x51];
    final input = BitcoinPsbtInputFacts(
      outpoint: (txId: '11' * 32, vout: 0),
      prevoutValueSat: 1,
      prevoutScriptPubkey: script,
      finalScriptSig: script,
      finalScriptWitness: witness,
      hasPartialSignatures: false,
      hasTaprootKeySignature: false,
      hasTaprootScriptSignatures: false,
    );
    witness.first[0] = 8;
    script[0] = 0;
    expect(input.prevoutScriptPubkey, [0x51]);
    expect(input.finalScriptSig, [0x51]);
    expect(input.finalScriptWitness, [
      [7],
    ]);
    expect(() => input.prevoutScriptPubkey[0] = 0, throwsUnsupportedError);
    expect(() => input.finalScriptSig?.clear(), throwsUnsupportedError);
    expect(() => input.finalScriptWitness?.clear(), throwsUnsupportedError);
    expect(
      () => input.finalScriptWitness?.first[0] = 0,
      throwsUnsupportedError,
    );
    final facts = _ok(
      _psbt(
        maps: [
          [
            ..._witness(),
            ..._entry([8], [1, 1, 7]),
          ],
        ],
      ),
    );
    expect(() => facts.inputs.clear(), throwsUnsupportedError);
    expect(() => facts.outputs.clear(), throwsUnsupportedError);
    expect(
      () => facts.outputs.first.scriptPubkey[0] = 0,
      throwsUnsupportedError,
    );
    expect(() => facts.finalTransaction?.bytes[0] = 0, throwsUnsupportedError);
  });

  test(
    'early refusal still cleans later eagerly materialized native input graphs',
    () {
      final second = [
        ..._witness(),
        ..._entry([4], [0x51]),
        ..._entry([5], [0x51]),
        ..._entry([6, ..._hex(_publicKey)], [1, 2, 3, 4, 0, 0, 0, 0]),
        ..._entry([7], []),
        ..._entry([0x15, 0xc0, ..._hex(_publicKey.substring(2))], [0x51, 0xc0]),
        ..._entry(
          [0x16, ..._hex(_publicKey.substring(2))],
          [0, 1, 2, 3, 4, 0, 0, 0, 0],
        ),
      ];
      for (var iteration = 0; iteration < 5; iteration++) {
        _refused(
          _psbt(
            inputs: [(txId: '11' * 32, vout: 0), (txId: '22' * 32, vout: 0)],
            maps: [[], second],
          ),
        );
      }
    },
  );

  test(
    'malformed, truncated, unsupported-version and oversized inputs refuse',
    () {
      final encoded = _psbt();
      for (final candidate in [
        '',
        'x',
        encoded.substring(0, encoded.length - 4),
        'A' * (maxEncodedBitcoinPsbtLength + 1),
      ]) {
        _refused(candidate);
      }
      _refused(
        base64Encode([
          0x70,
          0x73,
          0x62,
          0x74,
          0xff,
          ..._entry([0xfb], [2, 0, 0, 0]),
          0,
        ]),
      );
    },
  );

  test(
    'public inspection refuses oversized unsigned and previous transactions',
    () {
      final oversized = Uint8List(maxBitcoinTransactionBytes);
      _refused(_psbt(outputs: [_output(10000, oversized)]));
      final previous = _tx(
        [(txId: '22' * 32, vout: 0)],
        [_output(50000, oversized)],
      );
      _refused(
        _psbt(
          maps: [
            _entry([0], previous),
          ],
        ),
      );
    },
  );

  test(
    'canonical-global scanner bounds lengths and requires its terminator',
    () {
      const magic = [0x70, 0x73, 0x62, 0x74, 0xff];
      for (final body in <List<int>>[
        [],
        [0],
        [0xfd],
        [0xfd, 1, 0],
        [0xfe, 0, 1, 0, 0],
        [0xff],
        [1, 0, 0xff],
        [1, 0, 10, 1],
        [
          ..._entry([0], [1]),
        ],
        [
          ..._entry([0], [1]),
          ..._entry([0], [2]),
          0,
        ],
        [1, 0, ..._size(maxBitcoinTransactionBytes + 1)],
      ]) {
        expect(
          () => psbtUnsignedTransaction(base64Encode([...magic, ...body])),
          throwsFormatException,
        );
      }
      expect(
        psbtUnsignedTransaction(_psbt()),
        _tx(
          [(txId: '11' * 32, vout: 0)],
          [
            _output(10000, [0x51]),
          ],
        ),
      );
    },
  );
}
