import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/domain/usecases/mix_entropy_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/entropy_ceremony_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late EntropyPool pool;
  late EntropyCeremonyCubit cubit;

  setUp(() {
    pool = EntropyPool();
    cubit = EntropyCeremonyCubit(
      mixEntropyUsecase: MixEntropyUsecase(entropyPool: pool),
    )..start();
  });

  tearDown(() => cubit.close());

  void addSamples(int count) {
    for (var i = 0; i < count; i++) {
      cubit.addPointerSample(
        kind: i.isEven ? PointerSampleKind.down : PointerSampleKind.move,
        pointer: 1,
        x: i.toDouble(),
        y: i * 2.0,
        dx: 1.0,
        dy: -1.0,
        timestampMicros: 1000 + i,
        pressure: 1.0,
        radiusMajor: 4.0,
      );
    }
  }

  test('progress and deciles advance with pointer samples', () {
    expect(cubit.state.hasStarted, isFalse);
    addSamples(30);
    expect(cubit.state.hasStarted, isTrue);
    expect(cubit.state.decile, 1);
    expect(cubit.state.isComplete, isFalse);
  });

  test('completion satisfies the pool human-input gate', () {
    addSamples(EntropyCeremonyState.targetEventCount);

    expect(cubit.state.isComplete, isTrue);
    expect(cubit.state.progress, 1.0);
    expect(
      pool.extractWithOsEntropy(
        Uint8List.fromList(List.generate(64, (index) => index)),
        16,
      ),
      hasLength(16),
    );
  });

  test('partial touch input cannot satisfy the pool gate', () {
    addSamples(EntropyCeremonyState.targetEventCount - 1);

    expect(
      () => pool.extractWithOsEntropy(
        Uint8List.fromList(List.generate(64, (index) => index)),
        16,
      ),
      throwsA(isA<EntropyPoolNotReadyException>()),
    );
  });

  test('samples after completion are ignored', () {
    addSamples(EntropyCeremonyState.targetEventCount);
    addSamples(50);

    expect(cubit.state.eventCount, EntropyCeremonyState.targetEventCount);
  });

  test('start is idempotent', () {
    cubit.start();
    addSamples(EntropyCeremonyState.targetEventCount);

    expect(cubit.state.isComplete, isTrue);
  });
}
