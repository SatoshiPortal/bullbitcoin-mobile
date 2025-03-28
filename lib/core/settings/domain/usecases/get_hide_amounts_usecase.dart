
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class GetHideAmountsUsecase {
  final SettingsRepository _settingsRepository;

  GetHideAmountsUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<bool> execute() async {
    final hide = await _settingsRepository.getHideAmounts();
    return hide;
  }
}
