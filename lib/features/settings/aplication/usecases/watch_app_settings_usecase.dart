import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/domain/entities/app_settings.dart';

class WatchAppSettingsUsecase {
  final AppSettingsRepositoryPort _appSettingsRepository;

  WatchAppSettingsUsecase({
    required AppSettingsRepositoryPort appSettingsRepository,
  }) : _appSettingsRepository = appSettingsRepository;

  Stream<AppSettings> execute() {
    return _appSettingsRepository.watchSettingsChanges();
  }
}
