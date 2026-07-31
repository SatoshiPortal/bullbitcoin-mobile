import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/data/services/sources/imu_sensor_source.dart';
import 'package:bb_mobile/core/entropy/domain/usecases/collect_sensor_entropy_usecase.dart';
import 'package:bb_mobile/core/entropy/domain/usecases/mix_entropy_usecase.dart';
import 'package:bb_mobile/features/onboarding/presentation/entropy_ceremony_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late EntropyPool pool;
  late EntropyCeremonyCubit cubit;

  setUp(() {
    pool = EntropyPool(strengthenBudget: Duration.zero);
    cubit = EntropyCeremonyCubit(
      mixEntropyUsecase: MixEntropyUsecase(entropyPool: pool),
      collectSensorEntropyUsecase: CollectSensorEntropyUsecase(
        entropyPool: pool,
        // Never started in these tests: sensors need a real device.
        imuSensorSource: const ImuSensorSource(),
      ),
    );
  });

  tearDown(() => cubit.close());

  void addSamples(int count) {
    for (var i = 0; i < count; i++) {
      cubit.addPointerSample(
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

  test('completes at the target event count and stops counting', () {
    addSamples(EntropyCeremonyState.targetEventCount + 50);
    expect(cubit.state.isComplete, isTrue);
    expect(cubit.state.progress, 1.0);
    expect(cubit.state.decile, 10);
    expect(cubit.state.eventCount, EntropyCeremonyState.targetEventCount);
  });

  test('touch samples are additive only: the mandatory gate still holds', () {
    addSamples(EntropyCeremonyState.targetEventCount);
    expect(
      () => pool.extract(32),
      throwsA(isA<EntropyPoolNotSeededException>()),
    );
  });
}
