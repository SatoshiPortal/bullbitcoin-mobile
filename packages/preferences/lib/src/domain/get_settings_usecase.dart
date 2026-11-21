import 'package:preferences/src/domain/settings_repository.dart';
import 'package:preferences/src/domain/settings_entity.dart';

class GetSettingsUsecase {
  final SettingsRepository _settingsRepository;

  GetSettingsUsecase({required this._settingsRepository});

  Future<SettingsEntity> execute() async => await _settingsRepository.fetch();
}
