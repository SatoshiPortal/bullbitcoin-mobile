import 'package:bb_mobile/core/failures/failure.dart';

sealed class BackupSettingsFailure extends Failure {
  const BackupSettingsFailure([super.logMessage]);
}

final class BackupSettingsUnexpectedFailure extends BackupSettingsFailure {
  const BackupSettingsUnexpectedFailure([super.logMessage]);
}

final class BackupSettingsPersistenceFailure extends BackupSettingsFailure {
  const BackupSettingsPersistenceFailure([super.logMessage]);
}
