import 'package:bb_mobile/core/storage/migrations/004_legacy/migration01to02.dart';
import 'package:bb_mobile/core/storage/migrations/004_legacy/migration02to03.dart';
import 'package:bb_mobile/core/storage/migrations/004_legacy/migration03to04.dart';

Future<bool> legacyMigrateToV4(String fromVersion) async {
  if (fromVersion.startsWith('0.1')) {
    await doMigration0_1to0_2();
    await doMigration0_2to0_3();
    await doMigration0_3to0_4();
    return true;
  } else if (fromVersion.startsWith('0.2')) {
    await doMigration0_2to0_3();
    await doMigration0_3to0_4();
    return true;
  } else if (fromVersion.startsWith('0.3')) {
    await doMigration0_3to0_4();
    return true;
  } else if (fromVersion.startsWith('0.4')) {
    return true;
  }
  return false;
}
