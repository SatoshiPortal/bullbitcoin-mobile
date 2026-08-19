import 'dart:typed_data';

import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/domain/usecases/mix_entropy_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/entropy_ceremony_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

class RecordingEntropyPool extends EntropyPool {
  final samples = <Uint8List>[];

  @override
  void mixTouchSample(Uint8List data) {
    samples.add(Uint8List.fromList(data));
    super.mixTouchSample(data);
  }
}

void main() {
  late RecordingEntropyPool pool;
  late EntropyCeremonyCubit cubit;
  late int elapsedMicros;

  setUp(() {
    pool = RecordingEntropyPool();
    elapsedMicros = 0;
    cubit = EntropyCeremonyCubit(
      mixEntropyUsecase: MixEntropyUsecase(entropyPool: pool),
      elapsedMicroseconds: () => elapsedMicros,
    )..start();
  });

  tearDown(() => cubit.close());

  void addSamples(int count) {
    final firstIndex = cubit.state.eventCount;
    for (var offset = 0; offset < count; offset++) {
      final i = firstIndex + offset;
      elapsedMicros = i * 25000;
      cubit.addPointerSample(
        kind: i.isEven ? PointerSampleKind.down : PointerSampleKind.move,
        pointer: 1,
        deviceKind: 0,
        x: ((i * 37) % 101) * 9.5,
        y: ((i * 53) % 101) * 9.5,
        canvasWidth: 1000,
        canvasHeight: 1000,
        dx: 1.0,
        dy: -1.0,
        timestampMicros: 1000 + i,
        pressure: 1.0,
        radiusMajor: 4.0,
        radiusMinor: 3.0,
        size: 0.2,
        orientation: 0.1,
        tilt: 0.0,
        synthesized: false,
      );
    }
  }

  test('progress and deciles advance with pointer samples', () {
    expect(cubit.state.hasStarted, isFalse);
    addSamples(50);
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

  test('synthesized pointer samples do not advance the ceremony', () {
    final accepted = cubit.addPointerSample(
      kind: PointerSampleKind.move,
      pointer: 1,
      deviceKind: 0,
      x: 10,
      y: 20,
      canvasWidth: 1000,
      canvasHeight: 1000,
      dx: 1,
      dy: 1,
      timestampMicros: 1000,
      pressure: 1,
      radiusMajor: 4,
      radiusMinor: 3,
      size: 0.2,
      orientation: 0.1,
      tilt: 0,
      synthesized: true,
    );

    expect(accepted, isFalse);
    expect(cubit.state.eventCount, 0);
  });

  test('consecutive duplicate positions do not advance the ceremony', () {
    addSamples(1);

    final accepted = cubit.addPointerSample(
      kind: PointerSampleKind.move,
      pointer: 1,
      deviceKind: 0,
      x: 0,
      y: 0,
      canvasWidth: 1000,
      canvasHeight: 1000,
      dx: 0,
      dy: 0,
      timestampMicros: 2000,
      pressure: 1,
      radiusMajor: 4,
      radiusMinor: 3,
      size: 0.2,
      orientation: 0.1,
      tilt: 0,
      synthesized: false,
    );

    expect(accepted, isFalse);
    expect(cubit.state.eventCount, 1);
  });

  test('non-finite positions and deltas do not advance the ceremony', () {
    final accepted = cubit.addPointerSample(
      kind: PointerSampleKind.move,
      pointer: 1,
      deviceKind: 0,
      x: double.nan,
      y: 0,
      canvasWidth: 1000,
      canvasHeight: 1000,
      dx: 1,
      dy: 1,
      timestampMicros: 1000,
      pressure: 1,
      radiusMajor: 4,
      radiusMinor: 3,
      size: 0.2,
      orientation: 0.1,
      tilt: 0,
      synthesized: false,
    );

    expect(accepted, isFalse);
    expect(cubit.state.eventCount, 0);
  });

  test('serialized samples commit to device kind and sequence order', () {
    elapsedMicros = 100;
    cubit.addPointerSample(
      kind: PointerSampleKind.down,
      pointer: 7,
      deviceKind: 3,
      x: 100,
      y: 200,
      canvasWidth: 1000,
      canvasHeight: 1000,
      dx: 0,
      dy: 0,
      timestampMicros: 900,
      pressure: 1,
      radiusMajor: 4,
      radiusMinor: 3,
      size: 0.2,
      orientation: 0.1,
      tilt: 0,
      synthesized: false,
    );
    elapsedMicros = 200;
    cubit.addPointerSample(
      kind: PointerSampleKind.move,
      pointer: 7,
      deviceKind: 3,
      x: 101,
      y: 201,
      canvasWidth: 1000,
      canvasHeight: 1000,
      dx: 1,
      dy: 1,
      timestampMicros: 901,
      pressure: 1,
      radiusMajor: 4,
      radiusMinor: 3,
      size: 0.2,
      orientation: 0.1,
      tilt: 0,
      synthesized: false,
    );

    expect(pool.samples, hasLength(2));
    expect(
      pool.samples.first,
      hasLength(EntropyCeremonyCubit.serializedSampleBytes),
    );
    expect(ByteData.sublistView(pool.samples.first).getUint64(16), 0);
    expect(ByteData.sublistView(pool.samples.last).getUint64(16), 1);
    expect(ByteData.sublistView(pool.samples.first).getUint64(24), 3);
  });

  test('500 samples cannot complete before ten elapsed seconds', () {
    for (var i = 0; i < EntropyCeremonyState.targetEventCount; i++) {
      elapsedMicros = i * 10000;
      cubit.addPointerSample(
        kind: PointerSampleKind.move,
        pointer: 1,
        deviceKind: 0,
        x: ((i * 37) % 101) * 9.5,
        y: ((i * 53) % 101) * 9.5,
        canvasWidth: 1000,
        canvasHeight: 1000,
        dx: 1,
        dy: 1,
        timestampMicros: 1000 + i,
        pressure: 1,
        radiusMajor: 4,
        radiusMinor: 3,
        size: 0.2,
        orientation: 0.1,
        tilt: 0,
        synthesized: false,
      );
    }

    expect(cubit.state.eventCount, EntropyCeremonyState.targetEventCount);
    expect(cubit.state.isComplete, isFalse);

    elapsedMicros = EntropyCeremonyState.minimumElapsedDuration.inMicroseconds;
    final accepted = cubit.addPointerSample(
      kind: PointerSampleKind.move,
      pointer: 1,
      deviceKind: 0,
      x: 500,
      y: 500,
      canvasWidth: 1000,
      canvasHeight: 1000,
      dx: 1,
      dy: 1,
      timestampMicros: 2000,
      pressure: 1,
      radiusMajor: 4,
      radiusMinor: 3,
      size: 0.2,
      orientation: 0.1,
      tilt: 0,
      synthesized: false,
    );

    expect(accepted, isTrue);
    expect(cubit.state.isComplete, isTrue);
  });

  test('narrow repetitive movement cannot satisfy the coverage gate', () {
    for (var i = 0; i < EntropyCeremonyState.targetEventCount; i++) {
      elapsedMicros = i * 25000;
      cubit.addPointerSample(
        kind: PointerSampleKind.move,
        pointer: 1,
        deviceKind: 0,
        x: 100 + (i % 20).toDouble(),
        y: 200 + ((i * 7) % 20).toDouble(),
        canvasWidth: 1000,
        canvasHeight: 1000,
        dx: 1,
        dy: 1,
        timestampMicros: 1000 + i,
        pressure: 1,
        radiusMajor: 4,
        radiusMinor: 3,
        size: 0.2,
        orientation: 0.1,
        tilt: 0,
        synthesized: false,
      );
    }

    expect(cubit.state.isComplete, isFalse);
    expect(cubit.state.horizontalCoverage, lessThan(0.02));
    expect(cubit.state.verticalCoverage, lessThan(0.02));

    elapsedMicros += 25000;
    cubit.addPointerSample(
      kind: PointerSampleKind.move,
      pointer: 1,
      deviceKind: 0,
      x: 900,
      y: 210,
      canvasWidth: 1000,
      canvasHeight: 1000,
      dx: 1,
      dy: 1,
      timestampMicros: 2000,
      pressure: 1,
      radiusMajor: 4,
      radiusMinor: 3,
      size: 0.2,
      orientation: 0.1,
      tilt: 0,
      synthesized: false,
    );
    expect(cubit.state.isComplete, isFalse);

    elapsedMicros += 25000;
    cubit.addPointerSample(
      kind: PointerSampleKind.move,
      pointer: 1,
      deviceKind: 0,
      x: 500,
      y: 900,
      canvasWidth: 1000,
      canvasHeight: 1000,
      dx: 1,
      dy: 1,
      timestampMicros: 2001,
      pressure: 1,
      radiusMajor: 4,
      radiusMinor: 3,
      size: 0.2,
      orientation: 0.1,
      tilt: 0,
      synthesized: false,
    );

    expect(cubit.state.isComplete, isTrue);
  });

  test('start is idempotent', () {
    cubit.start();
    addSamples(EntropyCeremonyState.targetEventCount);

    expect(cubit.state.isComplete, isTrue);
  });
}
