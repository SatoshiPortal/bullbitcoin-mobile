import 'package:bb_mobile/core/settings/data/settings_repository.dart';

class SetExchangeTestnetBasicAuthUsecase {
  final SettingsRepository _settingsRepository;

  SetExchangeTestnetBasicAuthUsecase({required this._settingsRepository});

  Future<void> execute({String? username, String? password}) async {
    await _settingsRepository.setExchangeTestnetBasicAuth(
      username: username,
      password: password,
    );
  }
}
