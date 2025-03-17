import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class GetHideAmountsUseCase {
  final SettingsRepository _settingsRepository;

  GetHideAmountsUseCase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<bool> execute() async {
    final hide = await _settingsRepository.getHideAmounts();
    return hide;
  }
}
