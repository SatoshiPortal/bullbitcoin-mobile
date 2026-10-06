import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:meta/meta.dart';

class SetLanguageUsecase {
  final SettingsRepository _settingsRepository;

  const SetLanguageUsecase({required this._settingsRepository});

  @useResult
  Future<Result<void, SettingsFailure>> execute(Language language) async {
    final result = await _settingsRepository.setLanguage(language);

    return result.mapErr(
      (failure) => SettingsStorageFailure(failure.logMessage),
    );
  }
}
