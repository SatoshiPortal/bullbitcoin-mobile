import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:secrets/src/crypto/exceptions.dart';
import 'package:secrets/src/crypto/signers/pset_sighash.dart';

/// The PSET sighash guard, on hand-built PSET v2 bytes.
///
/// lwk_signer signs with whatever sighash an input asks for, so this guard is the only thing standing between a counterparty-authored PSET and a `SIGHASH_NONE` signature over the user's coins. The fixtures follow the PSET v2 framing (BIP 370 key-value maps, Elements' proprietary keys) closely enough that the parser meets the shapes lwk emits: globals with version and counts, inputs with previous outpoint, outputs with amount, script and a proprietary `pset` key.
void main() {
  List<int> compact(int n) =>
      n < 0xfd ? [n] : [0xfd, n & 0xff, (n >> 8) & 0xff];

  List<int> entry(int type, List<int> value, {List<int> keyData = const []}) {
    final key = [...compact(type), ...keyData];
    return [...compact(key.length), ...key, ...compact(value.length), ...value];
  }

  List<int> u32(int v) => [
    v & 0xff,
    (v >> 8) & 0xff,
    (v >> 16) & 0xff,
    (v >> 24) & 0xff,
  ];

  // Elements' proprietary key prefix: 0xfc, then "pset", then a subtype.
  final proprietary = entry(
    0xfc,
    List.filled(33, 7),
    keyData: [4, ...'pset'.codeUnits, 0x01],
  );

  List<int> input({int? sighash}) => [
    ...entry(0x0e, List.filled(32, 0xab)), // previous txid
    ...entry(0x0f, u32(0)), // previous output index
    if (sighash != null) ...entry(0x03, u32(sighash)),
    ...proprietary,
    0x00,
  ];

  final output = [
    ...entry(0x03, List.filled(8, 0)), // amount
    ...entry(0x04, [0x00, 0x14, ...List.filled(20, 1)]), // script
    ...proprietary,
    0x00,
  ];

  String pset(List<List<int>> inputs, {int outputs = 1, List<int>? tail}) =>
      base64.encode([
        0x70, 0x73, 0x65, 0x74, 0xff,
        ...entry(0x02, u32(2)), // tx version
        ...entry(0x04, compact(inputs.length)),
        ...entry(0x05, compact(outputs)),
        ...entry(0xfb, u32(2)), // PSET version 2
        0x00,
        for (final i in inputs) ...i,
        for (var o = 0; o < outputs; o++) ...output,
        ...?tail,
      ]);

  group('what is signed', () {
    test('an input with no sighash field is ALL, and is signed', () {
      expect(PsetSighash.sighashTypes(pset([input()])), [null]);
      expect(() => PsetSighash.requireAll(pset([input()])), returnsNormally);
    });

    test('an explicit SIGHASH_ALL is signed', () {
      final p = pset([input(sighash: 0x01), input()], outputs: 2);
      expect(PsetSighash.sighashTypes(p), [0x01, null]);
      expect(() => PsetSighash.requireAll(p), returnsNormally);
    });
  });

  group('what a counterparty cannot choose', () {
    for (final (name, type) in [
      ('NONE', 0x02),
      ('SINGLE', 0x03),
      ('ALL|ANYONECANPAY', 0x81),
      ('NONE|ANYONECANPAY', 0x82),
      ('SINGLE|ANYONECANPAY (LiquiDEX)', 0x83),
      ('ALL|RANGEPROOF', 0x41),
      ('an undefined value', 0x00),
    ]) {
      test('$name is refused', () {
        expect(
          () => PsetSighash.requireAll(pset([input(sighash: type)])),
          throwsA(isA<LiquidSigningFailed>()),
        );
      });
    }

    test('one bad input among good ones is enough to refuse', () {
      expect(
        () => PsetSighash.requireAll(
          pset([
            input(),
            input(sighash: 0x01),
            input(sighash: 0x02),
          ], outputs: 1),
        ),
        throwsA(isA<LiquidSigningFailed>()),
      );
    });
  });

  group('what cannot be read is not signed', () {
    for (final (name, value) in [
      ('not base64', 'not a pset'),
      ('bare magic', 'cHNldP8='),
      (
        'a PSBT, not a PSET',
        base64.encode([0x70, 0x73, 0x62, 0x74, 0xff, 0x00]),
      ),
      ('empty', ''),
    ]) {
      test('$name is refused', () {
        expect(
          () => PsetSighash.requireAll(value),
          throwsA(isA<LiquidSigningFailed>()),
        );
      });
    }

    test('a truncated PSET is refused', () {
      final bytes = base64.decode(pset([input()]));
      final cut = base64.encode(bytes.sublist(0, bytes.length - 5));
      expect(
        () => PsetSighash.requireAll(cut),
        throwsA(isA<LiquidSigningFailed>()),
      );
    });

    test('a sighash field of the wrong width is refused', () {
      final bad = [
        ...entry(0x03, [0x01]),
        0x00,
      ];
      expect(
        () => PsetSighash.requireAll(pset([bad])),
        throwsA(isA<LiquidSigningFailed>()),
      );
    });

    test('two sighash fields on one input are refused', () {
      final twice = [
        ...entry(0x03, u32(0x01)),
        ...entry(0x03, u32(0x01)),
        0x00,
      ];
      expect(
        () => PsetSighash.requireAll(pset([twice])),
        throwsA(isA<LiquidSigningFailed>()),
      );
    });

    test('an input count that the maps do not match is refused', () {
      // Two inputs announced, one present: the output map is read as an input and the end is short.
      final p = base64.encode([
        0x70,
        0x73,
        0x65,
        0x74,
        0xff,
        ...entry(0x04, [2]),
        ...entry(0x05, [1]),
        0x00,
        ...input(),
        ...output,
      ]);
      expect(
        () => PsetSighash.requireAll(p),
        throwsA(isA<LiquidSigningFailed>()),
      );
    });

    test('trailing bytes after the last map are refused', () {
      expect(
        () => PsetSighash.requireAll(pset([input()], tail: [0x01, 0x02])),
        throwsA(isA<LiquidSigningFailed>()),
      );
    });
  });
}
