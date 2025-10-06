import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema5To6 {
  static Future<void> migrate(Migrator m, Schema6 schema6) async {
    // Add isCustom column to electrum_servers table with default value false
    final electrumServers = schema6.electrumServers;
    await m.addColumn(electrumServers, electrumServers.isCustom);
  }
}
