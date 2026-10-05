import 'package:bb_mobile/core/failures/failure.dart';

sealed class SettingsFailure extends Failure {
  const SettingsFailure([super.logMessage]);
}

final class SettingsStorageFailure extends SettingsFailure {
  const SettingsStorageFailure([super.logMessage]);
}

final class SettingsConsentFailure extends SettingsFailure {
  const SettingsConsentFailure([super.logMessage]);
}

final class SettingsLogsFailure extends SettingsFailure {
  const SettingsLogsFailure([super.logMessage]);
}

final class SettingsSigningKeyExportFailure extends SettingsFailure {
  const SettingsSigningKeyExportFailure([super.logMessage]);
}

final class SettingsWalletPolicyFailure extends SettingsFailure {
  const SettingsWalletPolicyFailure([super.logMessage]);
}

final class SettingsWalletRegistrationFailure extends SettingsFailure {
  const SettingsWalletRegistrationFailure([super.logMessage]);
}
