import 'package:bb_mobile/core/failures/failure.dart';

sealed class SettingsFailure extends Failure {
  const SettingsFailure([super.logMessage]);
}

final class SettingsStorageFailure extends SettingsFailure {
  const SettingsStorageFailure([super.logMessage]);
}
