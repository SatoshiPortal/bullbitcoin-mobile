import 'package:bb_mobile/features/settings/domain/entities/app_settings.dart';

abstract class AppSettingsRepositoryPort {
  Future<void> saveSettings(AppSettings settings);
  Future<AppSettings> loadSettings();
  Stream<AppSettings> watchSettingsChanges();
}
