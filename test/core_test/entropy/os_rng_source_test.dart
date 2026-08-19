import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/sources/os_rng_source.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List validDraw([int offset = 0]) => Uint8List.fromList(
  List.generate(OsRngSource.bytesPerDraw, (index) => (index + offset) & 0xff),
);

void main() {
  test('returns an exact-length non-degenerate draw', () async {
    final source = OsRngSource(provider: validDraw);

    expect(await source.collect(), equals(validDraw()));
  });

  test('rejects malformed draw lengths', () async {
    final source = OsRngSource(provider: () => Uint8List(32));

    expect(source.collect, throwsA(isA<OsEntropyLengthException>()));
  });

  test('rejects an all-identical draw', () async {
    final source = OsRngSource(
      provider: () => Uint8List(OsRngSource.bytesPerDraw),
    );

    expect(source.collect, throwsA(isA<OsEntropySanityException>()));
  });

  test('rejects an exact repeat within the process', () async {
    final source = OsRngSource(provider: validDraw);
    await source.collect();

    expect(source.collect, throwsA(isA<OsEntropySanityException>()));
  });

  test('propagates provider failure without fallback', () {
    final source = OsRngSource(provider: () => throw StateError('rng failed'));

    expect(source.collect, throwsStateError);
  });
}
