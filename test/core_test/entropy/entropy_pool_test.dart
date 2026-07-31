import 'dart:convert';
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Re-implementation of the pool's specification in test code, used to
/// verify the production code against the construction on paper:
///
///   digest = SHA512(len(name) ‖ name ‖ counter ‖ len(data) ‖ data ‖ state)
///   state' = digest[32..64]
///   output = digest[0..32]   (extraction: SHA512(counter ‖ state))
///
/// This mirror alone cannot catch a shared misunderstanding, which is why
/// the known-answer group below also pins outputs to vectors computed by an
/// independent implementation (Python hashlib) of the same specification.
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

String hexOf(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  group('EntropyPool construction (known-answer)', () {
    // Computed by an independent Python (hashlib) implementation of the
    // specification: mix('os-rng', 0..63), mix('bdk-rng', 255..224),
    // extract(32). Big-endian 64-bit framing integers, zero initial state.
    const externalVector1 =
        '66dadc11fb507f0c14aef4ddb53cc7ea52af9598fe0428f927e7ba88cc07d380';
    // Same, with mix('touch', 1024 zero bytes) between the two mandatory
    // sources.
    const externalVector2 =
        'e0639105973bc23d54f32c834bf8cf5b77e37a9615ed031d583d35b1f0f4cc3b';

    test('extract matches the externally computed vector', () {
      final pool = deterministicPool();
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      expect(hexOf(pool.extract(32)), externalVector1);
    });

    test('supplemental data between mandatory sources matches the '
        'externally computed vector', () {
      final pool = deterministicPool();
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.touch, Uint8List(1024));
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      expect(hexOf(pool.extract(32)), externalVector2);
    });

    test('extract matches the in-test spec mirror', () {
      final pool = deterministicPool();
      final spec = SpecPool();

      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      spec.mix(EntropySourceName.osRng, osBytes);
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      spec.mix(EntropySourceName.bdkRng, bdkBytes);

      expect(pool.extract(32), equals(spec.extract()));
    });

    test('extraction returns the requested prefix length', () {
      final pool = deterministicPool();
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      final full = pool.extract(32);

      final pool16 = deterministicPool();
      pool16.mixMandatory(EntropySourceName.osRng, osBytes);
      pool16.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      expect(pool16.extract(16), equals(full.sublist(0, 16)));
    });
  });

  group('Additivity', () {
    test('adversarial supplemental data cannot cancel the unknown source', () {
      Uint8List run(Uint8List osDraw) {
        final pool = deterministicPool();
        pool.mixMandatory(EntropySourceName.osRng, osDraw);
        pool.mix(EntropySourceName.touch, Uint8List(1024));
        pool.mix(EntropySourceName.touch, osDraw); // copies another source
        pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
        return pool.extract(32);
      }

      final other = Uint8List.fromList(osBytes);
      other[0] ^= 1;
      expect(run(osBytes), isNot(equals(run(other))));
    });

    test('mixing the same data twice produces distinct states (counter)', () {
      final pool = deterministicPool();
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      final once = pool.extract(32);

      final pool2 = deterministicPool();
      pool2.mixMandatory(EntropySourceName.osRng, osBytes);
      pool2.mixMandatory(EntropySourceName.osRng, osBytes);
      pool2.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
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

    test('the supplemental mix path can NEVER satisfy the gate, even with '
        'mandatory source names', () {
      final pool = deterministicPool();
      pool.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.bdkRng, bdkBytes);
      expect(
        () => pool.extract(32),
        throwsA(isA<EntropyPoolNotSeededException>()),
      );
    });

    test('mixMandatory rejects non-mandatory source names', () {
      final pool = deterministicPool();
      expect(
        () => pool.mixMandatory(EntropySourceName.touch, osBytes),
        throwsArgumentError,
      );
    });

    test('mixMandatory rejects short reads', () {
      final pool = deterministicPool();
      expect(
        () => pool.mixMandatory(EntropySourceName.osRng, Uint8List(31)),
        throwsA(isA<MandatoryEntropyTooShortException>()),
      );
      expect(
        () => pool.mixMandatory(EntropySourceName.osRng, Uint8List(0)),
        throwsA(isA<MandatoryEntropyTooShortException>()),
      );
    });

    test('extract throws when only one mandatory source is mixed', () {
      final pool = deterministicPool();
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
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
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      pool.extract(32);
      expect(
        () => pool.extract(32),
        throwsA(isA<EntropyPoolNotSeededException>()),
      );
    });

    test('empty supplemental data is skipped silently', () {
      final pool = deterministicPool();
      final spec = SpecPool();
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      spec.mix(EntropySourceName.osRng, osBytes);
      pool.mix(EntropySourceName.touch, Uint8List(0));
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      spec.mix(EntropySourceName.bdkRng, bdkBytes);
      expect(pool.extract(32), equals(spec.extract()));
    });
  });

  group('Extraction limits and forward secrecy', () {
    test('rejects lengths outside 1..32', () {
      final pool = deterministicPool();
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      expect(() => pool.extract(0), throwsArgumentError);
      expect(() => pool.extract(33), throwsArgumentError);
    });

    test('consecutive extractions are unrelated at the output level', () {
      final pool = deterministicPool();
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      final first = pool.extract(32);
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      final second = pool.extract(32);
      expect(first, isNot(equals(second)));
    });

    test('strengthening (non-zero budget) still extracts 32 bytes', () {
      final pool = EntropyPool(); // default 10ms strengthen
      pool.mixMandatory(EntropySourceName.osRng, osBytes);
      pool.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      expect(pool.extract(32).length, 32);
    });
  });
}
