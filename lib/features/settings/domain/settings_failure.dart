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

final class SettingsPayjoinFailure extends SettingsFailure {
  const SettingsPayjoinFailure([super.logMessage]);
}
