import 'package:bb_mobile/core/entropy/data/services/entropy_collector.dart';
import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/data/services/sources/cpu_jitter_source.dart';
import 'package:bb_mobile/core/entropy/data/services/sources/imu_sensor_source.dart';
import 'package:bb_mobile/core/entropy/data/services/sources/os_rng_source.dart';
import 'package:bb_mobile/core/entropy/data/services/sources/system_stats_source.dart';
import 'package:bb_mobile/core/entropy/domain/usecases/collect_sensor_entropy_usecase.dart';
import 'package:bb_mobile/core/entropy/domain/usecases/mix_entropy_usecase.dart';
import 'package:get_it/get_it.dart';

class EntropyLocator {
  static void setup(GetIt locator) {
    // The pool is a process-wide singleton: entropy mixed anywhere (touch
    // ceremony, sensors, baseline collection) accumulates in one state.
    locator.registerLazySingleton<EntropyPool>(() => EntropyPool());

    locator.registerLazySingleton<ImuSensorSource>(
      () => const ImuSensorSource(),
    );

    locator.registerLazySingleton<EntropyCollector>(
      () => EntropyCollector(
        pool: locator<EntropyPool>(),
        sources: const [OsRngSource(), CpuJitterSource(), SystemStatsSource()],
      ),
    );

    locator.registerFactory<MixEntropyUsecase>(
      () => MixEntropyUsecase(entropyPool: locator<EntropyPool>()),
    );

    locator.registerFactory<CollectSensorEntropyUsecase>(
      () => CollectSensorEntropyUsecase(
        entropyPool: locator<EntropyPool>(),
        imuSensorSource: locator<ImuSensorSource>(),
      ),
    );
  }
}
