import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

/// Migration from version 13 to 14.
///
/// Adds wallet-owned behavior settings. The columns are nullable so feature
/// defaults can be applied only when missing without overwriting user choices.
class Schema13To14 {
  static Future<void> migrate(Migrator m, Schema14 schema14) async {
    try {
      await m.addColumn(
        schema14.walletMetadatas,
        schema14.walletMetadatas.hideOnHome,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }

    try {
      await m.addColumn(
        schema14.walletMetadatas,
        schema14.walletMetadatas.autoSweepEnabled,
      );
    } catch (e) {
      if (!e.toString().contains('duplicate column')) rethrow;
    }
  }
}
