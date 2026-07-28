import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class WatchPayjoinMinAmountChangesUsecase {
  final SettingsRepository _settingsRepository;

  WatchPayjoinMinAmountChangesUsecase({required this._settingsRepository});

  Stream<int> execute() => _settingsRepository.payjoinMinAmountChangeStream;
}
