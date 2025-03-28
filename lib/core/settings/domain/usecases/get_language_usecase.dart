
import 'package:bb_mobile/core/settings/domain/entity/settings.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';

class GetLanguageUsecase {
  final SettingsRepository _settingsRepository;

  GetLanguageUsecase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<Language?> execute() async {
    final language = await _settingsRepository.getLanguage();
    return language;
  }
}
