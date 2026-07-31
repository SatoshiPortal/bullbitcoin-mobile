import 'dart:async';
import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_collector.dart';
import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSource implements EntropySource {
  FakeSource({
    required this.name,
    required this.mandatory,
    this.error,
    this.hang = false,
  });

  @override
  final String name;
  @override
  final bool mandatory;
  final Object? error;
  final bool hang;

  @override
  Future<Uint8List> collect() async {
    if (hang) {
      return Completer<Uint8List>().future;
    }
    if (error != null) {
      throw error!;
    }
    return Uint8List.fromList(List.generate(64, (i) => i));
  }
}

void main() {
  final bdkBytes = Uint8List.fromList(List.filled(32, 7));

  EntropyPool pool() => EntropyPool(strengthenBudget: Duration.zero);

  test(
    'collects all sources and satisfies the OS RNG side of the gate',
    () async {
      final p = pool();
      final collector = EntropyCollector(
        pool: p,
        sources: [
          FakeSource(name: EntropySourceName.osRng, mandatory: true),
          FakeSource(name: EntropySourceName.cpuJitter, mandatory: false),
        ],
      );
      await collector.collectAll();
      p.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
      expect(p.extract(32).length, 32);
    },
  );

  test('a failing optional source is skipped, never blocks', () async {
    final p = pool();
    final collector = EntropyCollector(
      pool: p,
      sources: [
        FakeSource(name: EntropySourceName.osRng, mandatory: true),
        FakeSource(
          name: EntropySourceName.cpuJitter,
          mandatory: false,
          error: StateError('sensor broken'),
        ),
      ],
    );
    await collector.collectAll();
    p.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
    expect(p.extract(32).length, 32);
  });

  test('a hanging optional source times out and is skipped', () async {
    final p = pool();
    final collector = EntropyCollector(
      pool: p,
      sources: [
        FakeSource(name: EntropySourceName.osRng, mandatory: true),
        FakeSource(name: EntropySourceName.imu, mandatory: false, hang: true),
      ],
      perSourceTimeout: const Duration(milliseconds: 50),
    );
    await collector.collectAll();
    p.mixMandatory(EntropySourceName.bdkRng, bdkBytes);
    expect(p.extract(32).length, 32);
  });

  test('a failing mandatory source aborts collection', () async {
    final collector = EntropyCollector(
      pool: pool(),
      sources: [
        FakeSource(
          name: EntropySourceName.osRng,
          mandatory: true,
          error: StateError('no entropy'),
        ),
      ],
    );
    expect(
      () => collector.collectAll(),
      throwsA(isA<MandatoryEntropySourceFailedException>()),
    );
  });

  test('without collection the pool refuses to extract', () {
    expect(
      () => pool().extract(32),
      throwsA(isA<EntropyPoolNotSeededException>()),
    );
  });
}
