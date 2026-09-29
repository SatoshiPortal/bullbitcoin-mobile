import 'package:bb_mobile/core/failures/failure.dart';
import 'package:bb_mobile/core/primitives/payment_network.dart';

sealed class ReceiveFailure extends Failure {
  const ReceiveFailure([super.logMessage]);
}

final class ReceiveAmountOutOfBoundsFailure extends ReceiveFailure {
  final BigInt? limitAmountSat;
  final bool? isMinimum;

  const ReceiveAmountOutOfBoundsFailure({
    this.limitAmountSat,
    this.isMinimum,
    String? logMessage,
  }) : super(logMessage);
}

final class ReceiveInvalidInvoiceFailure extends ReceiveFailure {
  const ReceiveInvalidInvoiceFailure([super.logMessage]);
}

final class ReceiveSwapUnavailableFailure extends ReceiveFailure {
  const ReceiveSwapUnavailableFailure([super.logMessage]);
}

final class ReceiveSwapRouteUnavailableFailure extends ReceiveFailure {
  final PaymentNetwork? inNetwork;
  final PaymentNetwork? outNetwork;

  const ReceiveSwapRouteUnavailableFailure({
    this.inNetwork,
    this.outNetwork,
    String? logMessage,
  }) : super(logMessage);
}

final class ReceiveNetworkFailure extends ReceiveFailure {
  const ReceiveNetworkFailure([super.logMessage]);
}

final class ReceiveRateLimitedFailure extends ReceiveFailure {
  final Duration? retryAfter;

  const ReceiveRateLimitedFailure({this.retryAfter, String? logMessage})
    : super(logMessage);
}

final class ReceiveAmountAboveProtocolLimitFailure extends ReceiveFailure {
  final int limitAmountSat;

  const ReceiveAmountAboveProtocolLimitFailure({
    required this.limitAmountSat,
    String? logMessage,
  }) : super(logMessage);
}

/// Persisting the note as an address label failed.
final class ReceiveNoteNotSavedFailure extends ReceiveFailure {
  const ReceiveNoteNotSavedFailure([super.logMessage]);
}

/// No receive address could be derived for the selected wallet.
final class ReceiveAddressUnavailableFailure extends ReceiveFailure {
  const ReceiveAddressUnavailableFailure([super.logMessage]);
}

/// A payjoin receiver session could not be started for the current address.
/// Receiving still works — only the `pj=` endpoint is missing — so this must
/// stay distinguishable from a failure that blocks the whole receive.
final class ReceivePayjoinUnavailableFailure extends ReceiveFailure {
  const ReceivePayjoinUnavailableFailure([super.logMessage]);
}

/// Persisting the global payjoin on/off setting from the receive toggle
/// failed. Surfaced as a snackbar on the toggle — keep it to that one cause,
/// or unrelated payjoin settings problems start popping snackbars.
final class ReceivePayjoinSettingFailure extends ReceiveFailure {
  const ReceivePayjoinSettingFailure([super.logMessage]);
}

/// The payjoin policy (enabled + anti-probing minimum) could not be read.
/// The caller fails closed — payjoin off — rather than telling the user,
/// so this must stay distinct from [ReceivePayjoinSettingFailure].
final class ReceivePayjoinPolicyUnavailableFailure extends ReceiveFailure {
  const ReceivePayjoinPolicyUnavailableFailure([super.logMessage]);
}

/// Broadcasting the sender's original (non-payjoin) transaction failed.
final class ReceiveBroadcastOriginalTxFailure extends ReceiveFailure {
  const ReceiveBroadcastOriginalTxFailure([super.logMessage]);
}

/// The original transaction is no longer broadcastable — a competing
/// transaction became visible after the button was shown. Not surfaced to the
/// user: the payjoin and wallet watchers converge the screen on their own.
final class ReceiveBroadcastOriginalTxUnavailableFailure
    extends ReceiveFailure {
  const ReceiveBroadcastOriginalTxUnavailableFailure([super.logMessage]);
}

/// Catch-all. [logMessage] is for logs ONLY and MUST never reach the UI.
final class ReceiveUnexpectedFailure extends ReceiveFailure {
  const ReceiveUnexpectedFailure([super.logMessage]);
}
