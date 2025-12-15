import 'package:bb_mobile/core_deprecated/settings/data/settings_repository.dart';

class WatchCurrencyChangesUsecase {
  final SettingsRepository _settingsRepository;

  WatchCurrencyChangesUsecase({required SettingsRepository settingsRepository})
    : _settingsRepository = settingsRepository;

  Stream<String> execute() {
    try {
      return _settingsRepository.currencyChangeStream;
    } catch (e) {
      throw Exception('Failed to watch currency changes: $e');
    }
  }
}
