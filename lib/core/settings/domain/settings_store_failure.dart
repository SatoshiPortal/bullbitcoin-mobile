import 'package:bb_mobile/core/failures/failure.dart';

sealed class SettingsStoreFailure extends Failure {
  const SettingsStoreFailure([super.logMessage]);
}

/// The value could not be persisted, so the stored setting still holds its
/// previous value.
final class SettingsStoreWriteFailure extends SettingsStoreFailure {
  const SettingsStoreWriteFailure([super.logMessage]);
}
