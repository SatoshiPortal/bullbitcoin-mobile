import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema9To10 {
  static Future<void> migrate(Migrator m, Schema10 schema10) async {
    // Add useTorProxy and torProxyPort columns to electrumSettings table
    final electrumSettings = schema10.electrumSettings;
    await m.addColumn(electrumSettings, electrumSettings.useTorProxy);
    await m.addColumn(electrumSettings, electrumSettings.torProxyPort);
  }
}
