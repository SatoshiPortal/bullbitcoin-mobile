import 'package:bb_mobile/core/nfc/domain/nfc_failure.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:flutter/widgets.dart';

extension NfcFailureL10n on NfcFailure {
  String? toTranslated(BuildContext context) => switch (this) {
    NfcCancelledFailure() => null,
    NfcUnsupportedFailure() => context.loc.nfcNotAvailable,
    NfcDisabledFailure() => context.loc.nfcDisabled,
    NfcTimeoutFailure() => context.loc.nfcTimeout,
    NfcBusyFailure() => context.loc.nfcBusy,
    NfcTagLostFailure() => context.loc.nfcConnectionLost,
    NfcUnsupportedTagFailure() => context.loc.nfcUnsupportedTag,
    NfcInvalidPayloadFailure() => context.loc.nfcInvalidData,
    NfcWriteFailure() => context.loc.nfcWriteFailed,
    NfcUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
