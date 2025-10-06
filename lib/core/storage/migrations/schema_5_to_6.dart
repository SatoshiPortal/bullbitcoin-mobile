import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema5To6 {
  static Future<void> migrate(Migrator m, Schema6 schema6) async {
    final settings = schema6.settings;
    await m.addColumn(settings, settings.themeMode);
  }
}
