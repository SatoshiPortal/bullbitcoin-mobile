import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema6To7 {
  static Future<void> migrate(Migrator m, Schema7 schema7) async {
    // Add themeMode column to settings table
    final settings = schema7.settings;
    await m.addColumn(settings, settings.themeMode);
  }
}
