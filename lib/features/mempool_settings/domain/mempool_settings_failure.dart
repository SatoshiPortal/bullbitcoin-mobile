import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of failures shown on the mempool settings screen. Lifted from the
/// core [MempoolFailure] by the cubit and rendered via the presentation
/// `toTranslated` extension — the raw reason stays in [Failure.logMessage]
/// (logs only) and never reaches the UI.
sealed class MempoolSettingsFailure extends Failure {
  const MempoolSettingsFailure([super.logMessage]);
}

final class MempoolSettingsLoadFailure extends MempoolSettingsFailure {
  const MempoolSettingsLoadFailure([super.logMessage]);
}

final class MempoolSettingsSaveServerFailure extends MempoolSettingsFailure {
  const MempoolSettingsSaveServerFailure([super.logMessage]);
}

final class MempoolSettingsDeleteServerFailure extends MempoolSettingsFailure {
  const MempoolSettingsDeleteServerFailure([super.logMessage]);
}

final class MempoolSettingsUpdateFailure extends MempoolSettingsFailure {
  const MempoolSettingsUpdateFailure([super.logMessage]);
}

final class MempoolSettingsInvalidUrlFailure extends MempoolSettingsFailure {
  const MempoolSettingsInvalidUrlFailure([super.logMessage]);
}

final class MempoolSettingsSameAsDefaultFailure extends MempoolSettingsFailure {
  const MempoolSettingsSameAsDefaultFailure([super.logMessage]);
}

final class MempoolSettingsValidationTimeoutFailure
    extends MempoolSettingsFailure {
  const MempoolSettingsValidationTimeoutFailure([super.logMessage]);
}

final class MempoolSettingsValidationHostNotFoundFailure
    extends MempoolSettingsFailure {
  const MempoolSettingsValidationHostNotFoundFailure([super.logMessage]);
}

final class MempoolSettingsValidationTorNotRunningFailure
    extends MempoolSettingsFailure {
  const MempoolSettingsValidationTorNotRunningFailure([super.logMessage]);
}

final class MempoolSettingsValidationConnectionErrorFailure
    extends MempoolSettingsFailure {
  const MempoolSettingsValidationConnectionErrorFailure([super.logMessage]);
}

final class MempoolSettingsValidationNotMempoolServerFailure
    extends MempoolSettingsFailure {
  const MempoolSettingsValidationNotMempoolServerFailure([super.logMessage]);
}

final class MempoolSettingsValidationServerUnavailableFailure
    extends MempoolSettingsFailure {
  const MempoolSettingsValidationServerUnavailableFailure([super.logMessage]);
}

final class MempoolSettingsValidationServerErrorFailure
    extends MempoolSettingsFailure {
  const MempoolSettingsValidationServerErrorFailure([super.logMessage]);
}

final class MempoolSettingsValidationInvalidResponseFailure
    extends MempoolSettingsFailure {
  const MempoolSettingsValidationInvalidResponseFailure([super.logMessage]);
}

final class MempoolSettingsUnexpectedFailure extends MempoolSettingsFailure {
  const MempoolSettingsUnexpectedFailure([super.logMessage]);
}
