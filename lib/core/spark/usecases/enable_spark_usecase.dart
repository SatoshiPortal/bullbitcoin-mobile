import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/spark/errors.dart';
import 'package:bb_mobile/core/spark/usecases/get_spark_wallet_usecase.dart';

class EnableSparkUsecase {
  final GetSparkWalletUsecase _getSparkWalletUsecase;
  final SettingsRepository _settingsRepository;

  EnableSparkUsecase({
    required GetSparkWalletUsecase getSparkWalletUsecase,
    required SettingsRepository settingsRepository,
  }) : _getSparkWalletUsecase = getSparkWalletUsecase,
       _settingsRepository = settingsRepository;

  Future<void> execute() async {
    final settings = await _settingsRepository.fetch();
    if (settings.isDevModeEnabled != true) {
      throw SparkRequiresDevModeError();
    }

    await _getSparkWalletUsecase.execute(forceRefresh: true);
  }
}
