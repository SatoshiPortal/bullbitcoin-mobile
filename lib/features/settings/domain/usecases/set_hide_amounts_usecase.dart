import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';

class SetHideAmountsUsecase {
  final SettingsRepository _settingsRepository;

  SetHideAmountsUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(bool hide) async {
    await _settingsRepository.setHideAmounts(hide);
  }
}
