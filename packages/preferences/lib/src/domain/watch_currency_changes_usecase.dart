import 'package:preferences/src/domain/settings_repository.dart';

class WatchCurrencyChangesUsecase {
  final SettingsRepository _settingsRepository;

  WatchCurrencyChangesUsecase({required this._settingsRepository});

  Stream<String> execute() {
    try {
      return _settingsRepository.currencyChangeStream;
    } catch (e) {
      throw Exception('Failed to watch currency changes: $e');
    }
  }
}
