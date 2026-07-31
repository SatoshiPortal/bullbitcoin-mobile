import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/data/services/sources/os_rng_source.dart';
import 'package:bb_mobile/core/seed/data/services/mnemonic_generator.dart';
import 'package:bdk_dart/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';

Uint8List fixedOsDraw() => Uint8List.fromList(
  List.generate(OsRngSource.bytesPerDraw, (index) => index),
);

void completeCeremony(EntropyPool pool, {int variant = 0}) {
  pool.beginTouchCeremony();
  for (var i = 0; i < EntropyPool.requiredTouchSamples; i++) {
    pool.mixTouchSample(
      Uint8List.fromList(
        List.generate(80, (offset) => (i + offset + variant) & 0xff),
      ),
    );
  }
  pool.completeTouchCeremony();
}

MnemonicGenerator generatorFor(EntropyPool pool) => MnemonicGenerator(
  entropyPool: pool,
  osRngSource: OsRngSource(provider: fixedOsDraw),
);

void main() {
  test('generates a valid 12-word mnemonic from explicit entropy', () async {
    final pool = EntropyPool();
    completeCeremony(pool);

    final words = await generatorFor(pool).generate();

    expect(words, hasLength(12));
    final parsed = bdk.Mnemonic.fromString(mnemonic: words.join(' '));
    parsed.dispose();
  });

  test('fails without a completed human-entropy ceremony', () {
    final generator = generatorFor(EntropyPool());

    expect(
      generator.generate,
      throwsA(isA<FailedToGenerateMnemonicException>()),
    );
  });

  test('different touch transcripts change the mnemonic', () async {
    final firstPool = EntropyPool();
    final secondPool = EntropyPool();
    completeCeremony(firstPool);
    completeCeremony(secondPool, variant: 1);

    final first = await generatorFor(firstPool).generate();
    final second = await generatorFor(secondPool).generate();

    expect(first, isNot(equals(second)));
  });

  test('OS source failure never falls back to touch input', () {
    final pool = EntropyPool();
    completeCeremony(pool);
    final generator = MnemonicGenerator(
      entropyPool: pool,
      osRngSource: OsRngSource(
        provider: () => Uint8List(OsRngSource.bytesPerDraw),
      ),
    );

    expect(
      generator.generate,
      throwsA(isA<FailedToGenerateMnemonicException>()),
    );
  });
}
