import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class GetCurrencyUsecase {
  final SettingsRepository _settingsRepository;

  GetCurrencyUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<String> execute() async {
    final currencyCode = await _settingsRepository.getCurrency();
    return currencyCode;
  }
}
