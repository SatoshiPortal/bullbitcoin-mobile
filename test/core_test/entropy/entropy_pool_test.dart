import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Independent re-implementation of the pool's specification, used to
/// verify the production code against the construction on paper:
///
///   digest = SHA512(len(name) ‖ name ‖ counter ‖ len(data) ‖ data ‖ state)
///   state' = digest[32..64]
///   output = digest[0..32]   (extraction: SHA512(counter ‖ state))
class SpecPool {
  List<int> state = List.filled(32, 0);
  int counter = 0;

  static Uint8List u64(int value) {
    final bytes = Uint8List(8);
    ByteData.view(bytes.buffer).setUint64(0, value);
    return bytes;
  }

  void mix(String name, List<int> data) {
    if (data.isEmpty) return;
    final nameBytes = utf8.encode(name);
    final digest = sha512.convert([
      ...u64(nameBytes.length),
      ...nameBytes,
      ...u64(counter++),
      ...u64(data.length),
      ...data,
      ...state,
    ]).bytes;
    state = digest.sublist(32);
  }

  List<int> extract() {
    final digest = sha512.convert([...u64(counter++), ...state]).bytes;
    state = digest.sublist(32);
    return digest.sublist(0, 32);
  }
}

EntropyPool deterministicPool() => EntropyPool(strengthenBudget: Duration.zero);

final osBytes = Uint8List.fromList(List.generate(64, (i) => i));
final bdkBytes = Uint8List.fromList(List.generate(32, (i) => 255 - i));

void main() {
  group('EntropyPool construction (known-answer against spec)', () {
    test('extract matches the independently computed SHA-512 chain', () {
      final pool = deterministicPool();
      final spec = SpecPool();

      pool.mix(EntropySourceName.osRng, osBytes);
      spec.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      spec.mix(EntropySourceName.bdkRng, bdkBytes);

      expect(pool.extract(32), equals(spec.extract()));
    });

    test('same inputs always produce the same output', () {
      Uint8List run() {
        final pool = deterministicPool();
        pool.mix(EntropySourceName.osRng, osBytes);
        pool.mix(EntropySourceName.bdkRng, bdkBytes);
        return pool.extract(32);
      }

      expect(run(), equals(run()));
    });

    test('extraction returns the requested prefix length', () {
      final pool = deterministicPool();
      pool.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      final full = pool.extract(32);

      final pool16 = deterministicPool();
      pool16.mix(EntropySourceName.osRng, osBytes);
      pool16.mix(EntropySourceName.bdkRng, bdkBytes);
      expect(pool16.extract(16), equals(full.sublist(0, 16)));
    });
  });

  group('Additivity', () {
    test('adversarial data mixed between strong sources still yields the '
        'spec output and cannot cancel the unknown source', () {
      final adversarial = [
        Uint8List(1024), // all zeros
        osBytes, // a copy of another source's output
        Uint8List.fromList(List.filled(64, 0xAA)),
      ];

      final pool = deterministicPool();
      final spec = SpecPool();
      pool.mix(EntropySourceName.osRng, osBytes);
      spec.mix(EntropySourceName.osRng, osBytes);
      for (final data in adversarial) {
        pool.mix(EntropySourceName.touch, data);
        spec.mix(EntropySourceName.touch, data);
      }
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      spec.mix(EntropySourceName.bdkRng, bdkBytes);

      expect(pool.extract(32), equals(spec.extract()));
    });

    test('with attacker-controlled sources fixed, changing only the OS RNG '
        'bytes changes the output', () {
      Uint8List run(Uint8List osDraw) {
        final pool = deterministicPool();
        pool.mix(EntropySourceName.osRng, osDraw);
        pool.mix(EntropySourceName.touch, Uint8List(1024));
        pool.mix(EntropySourceName.bdkRng, bdkBytes);
        return pool.extract(32);
      }

      final other = Uint8List.fromList(osBytes);
      other[0] ^= 1;
      expect(run(osBytes), isNot(equals(run(other))));
    });

    test('mixing the same data twice produces distinct states (counter)', () {
      final pool = deterministicPool();
      pool.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      final once = pool.extract(32);

      final pool2 = deterministicPool();
      pool2.mix(EntropySourceName.osRng, osBytes);
      pool2.mix(EntropySourceName.osRng, osBytes);
      pool2.mix(EntropySourceName.bdkRng, bdkBytes);
      expect(pool2.extract(32), isNot(equals(once)));
    });
  });

  group('Mandatory source gate', () {
    test('extract throws before any mandatory source is mixed', () {
      expect(
        () => deterministicPool().extract(32),
        throwsA(isA<EntropyPoolNotSeededException>()),
      );
    });

    test('extract throws when only one mandatory source is mixed', () {
      final pool = deterministicPool();
      pool.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.touch, osBytes);
      expect(
        () => pool.extract(32),
        throwsA(
          isA<EntropyPoolNotSeededException>().having(
            (e) => e.message,
            'message',
            contains(EntropySourceName.bdkRng),
          ),
        ),
      );
    });

    test('gate re-arms after every extraction', () {
      final pool = deterministicPool();
      pool.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      pool.extract(32);
      expect(
        () => pool.extract(32),
        throwsA(isA<EntropyPoolNotSeededException>()),
      );
    });

    test('empty data never counts as mixed', () {
      final pool = deterministicPool();
      pool.mix(EntropySourceName.osRng, Uint8List(0));
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      expect(
        () => pool.extract(32),
        throwsA(isA<EntropyPoolNotSeededException>()),
      );
    });
  });

  group('Extraction limits and forward secrecy', () {
    test('rejects lengths outside 1..32', () {
      final pool = deterministicPool();
      pool.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      expect(() => pool.extract(0), throwsArgumentError);
      expect(() => pool.extract(33), throwsArgumentError);
    });

    test('consecutive extractions are unrelated at the output level', () {
      final pool = deterministicPool();
      pool.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      final first = pool.extract(32);
      pool.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      final second = pool.extract(32);
      expect(first, isNot(equals(second)));
    });

    test('strengthening (non-zero budget) still extracts 32 bytes', () {
      final pool = EntropyPool(); // default 10ms strengthen
      pool.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      expect(pool.extract(32).length, 32);
    });
  });
}
