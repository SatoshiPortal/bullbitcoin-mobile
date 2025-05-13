import 'package:bb_mobile/core/storage/migrations/legacy/migration01to02.dart';
import 'package:bb_mobile/core/storage/migrations/legacy/migration02to03.dart';

Future<void> doMigration(String fromVersion, String toVersion) async {
  if (toVersion.startsWith('0.2') && fromVersion.startsWith('0.1')) {
    await doMigration0_1to0_2();
  } else if (toVersion.startsWith('0.3')) {
    if (fromVersion.startsWith('0.1')) {
      await doMigration0_1to0_2();
      await doMigration0_2to0_3();
    } else if (fromVersion.startsWith('0.2')) {
      await doMigration0_2to0_3();
    }
  } else if (toVersion.startsWith('0.4')) {
    if (fromVersion.startsWith('0.1')) {
      await doMigration0_1to0_2();
      await doMigration0_2to0_3();
      await doMigration0_3to0_4();
    } else if (fromVersion.startsWith('0.2')) {
      await doMigration0_2to0_3();
      await doMigration0_3to0_4();
    } else if (fromVersion.startsWith('0.3')) {
      await doMigration0_3to0_4();
    }
  }
}

Future<void> doMigration0_3to0_4() async {}
