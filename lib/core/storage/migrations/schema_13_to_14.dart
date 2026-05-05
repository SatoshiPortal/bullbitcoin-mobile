import 'package:bb_mobile/core/storage/sqlite_database.steps.dart';
import 'package:drift/drift.dart';

class Schema13To14 {
  static Future<void> migrate(Migrator m, Schema14 schema14) async {
    await m.addColumn(schema14.posProfiles, schema14.posProfiles.allowLiquid);
    await m.addColumn(
      schema14.posProfiles,
      schema14.posProfiles.allowLightning,
    );
    await m.addColumn(schema14.posProfiles, schema14.posProfiles.allowBoltCard);
  }
}
