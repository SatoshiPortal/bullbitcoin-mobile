import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_settings_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each Electrum settings failure. The
/// `sealed` switch makes a missing message a compile error. Never returns the
/// raw [Failure.logMessage].
extension ElectrumServersFailureL10n on ElectrumServersFailure {
  String toTranslated(BuildContext context) => switch (this) {
    ElectrumServersLoadFailure() => context.loc.electrumLoadFailedError,
    ElectrumServersSavePriorityFailure() =>
      context.loc.electrumSavePriorityFailedError,
    ElectrumServerAddFailure() => context.loc.electrumAddFailedError,
    ElectrumServerDeleteFailure() => context.loc.electrumDeleteFailedError,
    ElectrumServerAlreadyExistsFailure() =>
      context.loc.electrumServerAlreadyExists,
    ElectrumServersUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}

extension AdvancedOptionsFailureL10n on AdvancedOptionsFailure {
  String toTranslated(BuildContext context) => switch (this) {
    AdvancedOptionsInvalidStopGapFailure(:final value) =>
      context.loc.electrumInvalidStopGapError(value),
    AdvancedOptionsInvalidTimeoutFailure(:final value) =>
      context.loc.electrumInvalidTimeoutError(value),
    AdvancedOptionsInvalidRetryFailure(:final value) =>
      context.loc.electrumInvalidRetryError(value),
    AdvancedOptionsSaveFailure() => context.loc.electrumSaveFailedError,
    AdvancedOptionsUnexpectedFailure() => context.loc.electrumUnknownError,
  };
}
