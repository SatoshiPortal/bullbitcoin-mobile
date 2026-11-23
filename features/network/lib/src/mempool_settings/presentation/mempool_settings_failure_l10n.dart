import 'package:mempool/mempool.dart';

import '../../network_l10n.dart';

import 'package:flutter/widgets.dart';

/// User-facing, localized message for each mempool failure on the settings
/// screen. The `sealed` switch makes a missing message a compile error. Never
/// returns the raw [Failure.logMessage].
extension MempoolFailureL10n on MempoolFailure {
  String toTranslated(BuildContext context) => switch (this) {
    MempoolLoadFailure() ||
    MempoolUnsupportedNetworkFailure() => context.loc.mempoolErrorLoadFailed,
    MempoolSaveFailure() => context.loc.mempoolErrorSaveServerFailed,
    MempoolDeleteFailure() => context.loc.mempoolErrorDeleteFailed,
    MempoolInvalidUrlFailure() => context.loc.mempoolErrorInvalidUrl,
    MempoolServerSameAsDefaultFailure() =>
      context.loc.mempoolErrorSameAsDefault,
    MempoolValidationTimeoutFailure() =>
      context.loc.mempoolErrorConnectionTimeout,
    MempoolValidationHostNotFoundFailure() =>
      context.loc.mempoolErrorHostNotFound,
    MempoolValidationTorNotRunningFailure() =>
      context.loc.mempoolErrorOnionRouteUnavailable,
    MempoolValidationConnectionErrorFailure() =>
      context.loc.mempoolErrorConnectionFailed,
    MempoolValidationNotMempoolServerFailure() =>
      context.loc.mempoolErrorNotMempoolServer,
    MempoolValidationServerUnavailableFailure() =>
      context.loc.mempoolErrorServerUnavailable,
    MempoolValidationServerErrorFailure() =>
      context.loc.mempoolErrorServerError,
    MempoolValidationInvalidResponseFailure() =>
      context.loc.mempoolErrorInvalidResponse,
    MempoolValidationNetworkMismatchFailure() =>
      context.loc.mempoolErrorNetworkMismatch,
    MempoolStorageUnavailableFailure() => context.loc.oopsSomethingWentWrong,
    MempoolUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
