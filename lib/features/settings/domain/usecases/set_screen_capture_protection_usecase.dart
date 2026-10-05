import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetScreenCaptureProtectionUsecase {
  final SettingsRepository _settingsRepository;

  const SetScreenCaptureProtectionUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(bool enabled) async {
    final result = await _settingsRepository.setScreenCaptureProtectionEnabled(
      enabled,
    );

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
