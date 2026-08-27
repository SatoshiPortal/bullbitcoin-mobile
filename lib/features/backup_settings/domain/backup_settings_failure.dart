import 'package:bb_mobile/core/failures/failure.dart';

sealed class BackupSettingsFailure extends Failure {
  const BackupSettingsFailure([super.logMessage]);
}

final class BackupSettingsUnexpectedFailure extends BackupSettingsFailure {
  const BackupSettingsUnexpectedFailure([super.logMessage]);
}

final class BackupSettingsUnavailableFailure extends BackupSettingsFailure {
  const BackupSettingsUnavailableFailure();
}

final class BackupSettingsDisabledFailure extends BackupSettingsFailure {
  const BackupSettingsDisabledFailure();
}

final class BackupSettingsUpdateRequiredFailure extends BackupSettingsFailure {
  const BackupSettingsUpdateRequiredFailure();
}
