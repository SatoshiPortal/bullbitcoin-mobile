import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class GetCurrencyUseCase {
  final SettingsRepository _settingsRepository;

  GetCurrencyUseCase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<String> execute() async {
    final currencyCode = await _settingsRepository.getCurrency();
    return currencyCode;
  }
}
