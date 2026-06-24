import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/mempool_settings/domain/mempool_settings_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each mempool settings failure. The
/// `sealed` switch makes a missing message a compile error. Never returns the
/// raw [Failure.logMessage].
extension MempoolSettingsFailureL10n on MempoolSettingsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    MempoolSettingsLoadFailure() => context.loc.mempoolErrorLoadFailed,
    MempoolSettingsSaveServerFailure() =>
      context.loc.mempoolErrorSaveServerFailed,
    MempoolSettingsDeleteServerFailure() =>
      context.loc.mempoolErrorDeleteFailed,
    MempoolSettingsUpdateFailure() =>
      context.loc.mempoolErrorUpdateSettingsFailed,
    MempoolSettingsInvalidUrlFailure() => context.loc.mempoolErrorInvalidUrl,
    MempoolSettingsSameAsDefaultFailure() =>
      context.loc.mempoolErrorSameAsDefault,
    MempoolSettingsValidationTimeoutFailure() =>
      context.loc.mempoolErrorConnectionTimeout,
    MempoolSettingsValidationHostNotFoundFailure() =>
      context.loc.mempoolErrorHostNotFound,
    MempoolSettingsValidationTorNotRunningFailure() =>
      context.loc.mempoolErrorTorNotRunning,
    MempoolSettingsValidationConnectionErrorFailure() =>
      context.loc.mempoolErrorConnectionFailed,
    MempoolSettingsValidationNotMempoolServerFailure() =>
      context.loc.mempoolErrorNotMempoolServer,
    MempoolSettingsValidationServerUnavailableFailure() =>
      context.loc.mempoolErrorServerUnavailable,
    MempoolSettingsValidationServerErrorFailure() =>
      context.loc.mempoolErrorServerError,
    MempoolSettingsValidationInvalidResponseFailure() =>
      context.loc.mempoolErrorInvalidResponse,
    MempoolSettingsUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
