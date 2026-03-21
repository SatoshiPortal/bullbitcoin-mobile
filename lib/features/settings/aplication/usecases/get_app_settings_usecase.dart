import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/aplication/settings_application_errors.dart';
import 'package:bb_mobile/features/settings/domain/entities/app_settings.dart';

class GetAppSettingsUsecase {
  final AppSettingsRepositoryPort _appSettingsRepository;

  GetAppSettingsUsecase({
    required AppSettingsRepositoryPort appSettingsRepository,
  }) : _appSettingsRepository = appSettingsRepository;

  Future<AppSettings> execute() async {
    try {
      final appSettings = await _appSettingsRepository.loadSettings();
      return appSettings;
    } catch (e) {
      throw FailedToGetAppSettings('Failed to get app settings: $e');
    }
  }
}
