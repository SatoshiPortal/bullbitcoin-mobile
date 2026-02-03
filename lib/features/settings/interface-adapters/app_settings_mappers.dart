import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/domain/entities/app_settings.dart';

extension AppSettingsRowMappersX on AppSettingsRow {
  AppSettings toDomain() {}
}

extension AppSettingsMappersX on AppSettings {
  AppSettingsRow toRow() {}
}
