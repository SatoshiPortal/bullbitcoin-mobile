import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetThemeModeUsecase {
  final SettingsRepository _settingsRepository;

  const SetThemeModeUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(AppThemeMode themeMode) async {
    final result = await _settingsRepository.setThemeMode(themeMode);

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
