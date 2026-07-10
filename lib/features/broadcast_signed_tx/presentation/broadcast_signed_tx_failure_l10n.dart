import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/broadcast_signed_tx/domain/broadcast_signed_tx_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [BroadcastSignedTxFailure]. The
/// `sealed` switch makes a missing message a compile error. Never returns the
/// raw `logMessage`.
extension BroadcastSignedTxFailureL10n on BroadcastSignedTxFailure {
  String toTranslated(BuildContext context) => switch (this) {
    InvalidTransactionFailure() =>
      context.loc.broadcastSignedTxErrorInvalidTransaction,
    InvalidPushTxFailure() => context.loc.broadcastSignedTxErrorInvalidPushTx,
    BroadcastFailedFailure() => context.loc.broadcastSignedTxBroadcastError,
    BroadcastUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
