import 'package:primitives/primitives.dart' show Failure;

sealed class PreferencesFailure extends Failure {
  const PreferencesFailure([super.logMessage]);
}

final class PreferencesWriteFailure extends PreferencesFailure {
  const PreferencesWriteFailure([super.logMessage]);
}

final class PreferencesReadFailure extends PreferencesFailure {
  const PreferencesReadFailure([super.logMessage]);
}

final class PreferencesMissingFailure extends PreferencesFailure {
  const PreferencesMissingFailure();
}

final class PreferencesInvalidFailure extends PreferencesFailure {
  const PreferencesInvalidFailure();
}

final class PreferencesStorageFailure extends PreferencesFailure {
  final bool deferred;
  const PreferencesStorageFailure({this.deferred = false});
}
