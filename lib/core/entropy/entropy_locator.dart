import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/data/services/sources/os_rng_source.dart';
import 'package:bb_mobile/core/entropy/domain/usecases/mix_entropy_usecase.dart';
import 'package:get_it/get_it.dart';

class EntropyLocator {
  static void setup(GetIt locator) {
    // The pool is process-wide so its secret state survives across creation
    // attempts for the lifetime of the app process.
    locator.registerLazySingleton<EntropyPool>(() => EntropyPool());

    locator.registerLazySingleton<OsRngSource>(() => OsRngSource());

    locator.registerFactory<MixEntropyUsecase>(
      () => MixEntropyUsecase(entropyPool: locator<EntropyPool>()),
    );
  }
}
