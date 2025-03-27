import 'package:bb_mobile/core/domain/entities/settings.dart';
import 'package:bb_mobile/core/domain/repositories/settings_repository.dart';

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
