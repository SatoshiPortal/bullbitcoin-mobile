import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/spark/usecases/disable_spark_usecase.dart';
import 'package:bb_mobile/core/spark/usecases/enable_spark_usecase.dart';
import 'package:bb_mobile/core/spark/usecases/get_spark_wallet_usecase.dart';
import 'package:bb_mobile/locator.dart';

class SparkCoreLocator {
  static void setup() {
    // Use cases
    locator.registerFactory<GetSparkWalletUsecase>(
      () => GetSparkWalletUsecase(
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<EnableSparkUsecase>(
      () => EnableSparkUsecase(
        getSparkWalletUsecase: locator<GetSparkWalletUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );

    locator.registerFactory<DisableSparkUsecase>(
      () => DisableSparkUsecase(
        getSparkWalletUsecase: locator<GetSparkWalletUsecase>(),
      ),
    );
  }
}
