import 'package:primitives/primitives.dart';

import 'entities/backup_settings.dart';
import 'recoverbull_failure.dart';

abstract interface class RecoverBullLegacySettingsPort {
  Future<Result<LegacyBackupSettings, RecoverBullFailure>> read();
}
