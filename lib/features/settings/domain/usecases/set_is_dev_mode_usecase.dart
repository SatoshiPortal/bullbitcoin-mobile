import 'package:bull_logger/bull_logger.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:primitives/primitives.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetIsDevModeUsecase {
  final SettingsRepository _settingsRepository;

  const SetIsDevModeUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(bool isEnabled) async {
    final result = await _settingsRepository.setIsDevMode(isEnabled);

    if (result is Ok) {
      log.config(
        'Developer mode saved enabled=$isEnabled${isEnabled ? '' : ' network=mainnet'}',
      );
    }
    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
