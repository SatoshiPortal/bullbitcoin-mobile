import 'package:bb_mobile/_core/domain/entities/settings.dart';
import 'package:bb_mobile/_core/domain/repositories/settings_repository.dart';

class GetLanguageUseCase {
  final SettingsRepository _settingsRepository;

  GetLanguageUseCase({
    required SettingsRepository settingsRepository,
  }) : _settingsRepository = settingsRepository;

  Future<Language?> execute() async {
    final language = await _settingsRepository.getLanguage();
    return language;
  }
}
