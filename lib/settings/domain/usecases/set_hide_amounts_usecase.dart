import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class SetHideAmountsUseCase {
  final SettingsRepository _settingsRepository;

  SetHideAmountsUseCase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<void> execute(bool hide) async {
    await _settingsRepository.setHideAmounts(hide);
  }
}
