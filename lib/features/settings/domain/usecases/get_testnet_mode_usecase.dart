import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bull_logger/bull_logger.dart';

class GetTestnetModeUsecase {
  const GetTestnetModeUsecase(this._settingsRepository);

  final SettingsRepository _settingsRepository;

  Future<Result<bool, SettingsFailure>> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      return Ok(settings.environment.isTestnet);
    } on Exception catch (error, stackTrace) {
      const message = 'Failed to read the exchange environment';
      log.warning(message, error: error, trace: stackTrace);
      return const Err(SettingsStorageFailure(message));
    }
  }
}
