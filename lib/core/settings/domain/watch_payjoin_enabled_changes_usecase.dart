import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class WatchPayjoinEnabledChangesUsecase {
  final SettingsRepository _settingsRepository;

  WatchPayjoinEnabledChangesUsecase({required this._settingsRepository});

  Stream<bool> execute() {
    try {
      return _settingsRepository.payjoinEnabledChangeStream;
    } catch (e) {
      throw Exception('Failed to watch payjoin enabled changes: $e');
    }
  }
}
