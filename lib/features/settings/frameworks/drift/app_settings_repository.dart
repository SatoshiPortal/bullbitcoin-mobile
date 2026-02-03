import 'package:bb_mobile/core/storage/sqlite_database.dart';
import 'package:bb_mobile/features/settings/aplication/ports/app_settings_repository_port.dart';
import 'package:bb_mobile/features/settings/domain/entities/app_settings.dart';
import 'package:bb_mobile/features/settings/frameworks/drift/app_settings_mapper.dart';
import 'package:drift/drift.dart';

/// Drift-based implementation of AppSettingsRepositoryPort.
///
/// This repository is in the frameworks layer because it directly depends on
/// Drift (a specific persistence framework). The mapper is also here to keep
/// all Drift-specific code isolated.
class DriftAppSettingsRepository implements AppSettingsRepositoryPort {
  final SqliteDatabase _database;

  DriftAppSettingsRepository({required SqliteDatabase database})
    : _database = database;

  @override
  Future<AppSettings> loadSettings() async {
    // App settings is a single-row table, always get the first row
    final row = await (_database.select(
      _database.appSettings,
    )..limit(1)).getSingleOrNull();

    // If no row exists, insert defaults (schema defaults will be used)
    // This should never happen though since we seed a row on DB creation
    // and migrations. But just in case, we handle it here as it is expected
    // by the port interface that this method always returns a valid AppSettings
    // instance.
    if (row == null) {
      await _database
          .into(_database.appSettings)
          .insert(const AppSettingsCompanion());
      // Fetch the newly created row
      final newRow = await (_database.select(
        _database.appSettings,
      )..limit(1)).getSingle();
      return AppSettingsMapper.toDomain(newRow);
    }

    return AppSettingsMapper.toDomain(row);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final companion = AppSettingsMapper.toCompanion(settings);

    // Update the first row (always id=1)
    await (_database.update(
      _database.appSettings,
    )..where((tbl) => tbl.id.equals(1))).write(companion);
  }

  @override
  Stream<AppSettings> watchSettingsChanges() {
    return (_database.select(
      _database.appSettings,
    )..limit(1)).watchSingle().map(AppSettingsMapper.toDomain);
  }
}
