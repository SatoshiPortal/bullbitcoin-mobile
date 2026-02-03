import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/domain/entities/app_settings.dart';

class AppSettingsRepository implements AppSettingsRepositoryPort {
  final SqliteDatabase _database;

  AppSettingsRepository({required SqliteDatabase database})
    : _database = database;

  @override
  Future<AppSettings> loadSettings() {
    // TODO: implement loadSettings
    throw UnimplementedError();
  }

  @override
  Future<void> saveSettings(AppSettings settings) {
    // TODO: implement saveSettings
    throw UnimplementedError();
  }

  @override
  Stream<AppSettings> watchSettingsChanges() {
    // TODO: implement watchSettingsChanges
    throw UnimplementedError();
  }
}
