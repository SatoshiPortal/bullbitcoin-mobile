import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:flutter_test/flutter_test.dart';

final osBytes = Uint8List.fromList(List.generate(64, (index) => index));

Uint8List touchSample(int index, {int variant = 0}) => Uint8List.fromList(
  List.generate(80, (offset) => (index + offset + variant) & 0xff),
);

void completeCeremony(EntropyPool pool, {int variant = 0}) {
  pool.beginTouchCeremony();
  for (var i = 0; i < EntropyPool.requiredTouchSamples; i++) {
    pool.mixTouchSample(touchSample(i, variant: variant));
  }
  pool.completeTouchCeremony();
}

String hexOf(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('known-answer construction', () {
    test('matches the independently computed SHA-512 vector', () {
      // Computed with Python hashlib from the versioned framing in
      // EntropyPool: ceremony 1, 500 deterministic 80-byte touch samples,
      // OS bytes 0..63, then a 32-byte extraction.
      const externalVector =
          '9f2a1182ba107634ff8ebff3f4c6b74e24c2185acacca768ffb2216db6e1d27a';
      final pool = EntropyPool();
      completeCeremony(pool);

      expect(hexOf(pool.extractWithOsEntropy(osBytes, 32)), externalVector);
    });

    test('a shorter extraction is the prefix of the same construction', () {
      final fullPool = EntropyPool();
      completeCeremony(fullPool);
      final full = fullPool.extractWithOsEntropy(osBytes, 32);

      final shortPool = EntropyPool();
      completeCeremony(shortPool);
      expect(
        shortPool.extractWithOsEntropy(osBytes, 16),
        equals(full.sublist(0, 16)),
      );
    });
  });

  group('required sources', () {
    test('extraction requires a completed touch ceremony', () {
      expect(
        () => EntropyPool().extractWithOsEntropy(osBytes, 16),
        throwsA(isA<EntropyPoolNotReadyException>()),
      );
    });

    test('a ceremony cannot complete below the sample target', () {
      final pool = EntropyPool()..beginTouchCeremony();
      for (var i = 0; i < EntropyPool.requiredTouchSamples - 1; i++) {
        pool.mixTouchSample(touchSample(i));
      }

      expect(
        pool.completeTouchCeremony,
        throwsA(isA<TouchEntropyCeremonyIncompleteException>()),
      );

      pool.mixTouchSample(touchSample(EntropyPool.requiredTouchSamples - 1));
      pool.completeTouchCeremony();
      expect(pool.extractWithOsEntropy(osBytes, 16), hasLength(16));
    });

    test('touch samples require an active ceremony', () {
      final pool = EntropyPool();
      expect(
        () => pool.mixTouchSample(touchSample(0)),
        throwsA(isA<TouchEntropyCeremonyStateException>()),
      );

      completeCeremony(pool);
      expect(
        () => pool.mixTouchSample(touchSample(0)),
        throwsA(isA<TouchEntropyCeremonyStateException>()),
      );
    });

    test('a short OS draw fails without consuming the ceremony', () {
      final pool = EntropyPool();
      completeCeremony(pool);

      expect(
        () => pool.extractWithOsEntropy(Uint8List(31), 16),
        throwsA(isA<OsEntropyTooShortException>()),
      );
      expect(pool.extractWithOsEntropy(osBytes, 16), hasLength(16));
    });

    test('the ceremony gate is consumed after extraction', () {
      final pool = EntropyPool();
      completeCeremony(pool);
      pool.extractWithOsEntropy(osBytes, 16);

      expect(
        () => pool.extractWithOsEntropy(osBytes, 16),
        throwsA(isA<EntropyPoolNotReadyException>()),
      );
    });

    test('starting again invalidates an unconsumed completion', () {
      final pool = EntropyPool();
      completeCeremony(pool);
      pool.beginTouchCeremony();

      expect(
        () => pool.extractWithOsEntropy(osBytes, 16),
        throwsA(isA<EntropyPoolNotReadyException>()),
      );
    });
  });

  group('source contribution and state', () {
    Uint8List run({int touchVariant = 0, int osVariant = 0}) {
      final pool = EntropyPool();
      completeCeremony(pool, variant: touchVariant);
      final os = Uint8List.fromList(osBytes);
      os[0] ^= osVariant;
      return pool.extractWithOsEntropy(os, 16);
    }

    test('different touch transcripts change the output', () {
      expect(run(), isNot(equals(run(touchVariant: 1))));
    });

    test('different OS draws change the output', () {
      expect(run(), isNot(equals(run(osVariant: 1))));
    });

    test('retained state separates repeated input across ceremonies', () {
      final pool = EntropyPool();
      completeCeremony(pool);
      final first = pool.extractWithOsEntropy(osBytes, 16);
      completeCeremony(pool);
      final second = pool.extractWithOsEntropy(osBytes, 16);

      expect(first, isNot(equals(second)));
    });
  });

  test('rejects extraction lengths outside 1..32', () {
    final pool = EntropyPool();
    completeCeremony(pool);
    expect(() => pool.extractWithOsEntropy(osBytes, 0), throwsArgumentError);
    expect(() => pool.extractWithOsEntropy(osBytes, 33), throwsArgumentError);
  });
}
