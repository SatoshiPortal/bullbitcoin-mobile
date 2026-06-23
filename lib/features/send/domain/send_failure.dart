import 'package:bb_mobile/core/failures/failure.dart';

/// Closed set of every failure the send flow surfaces to the user.
///
/// Foreign errors (BDK, LWK, Boltz, Electrum, payjoin, drift) are caught at the
/// first layer the feature owns — its use-cases, or the cubit when it
/// orchestrates a still-throwing core use-case — logged with their raw reason,
/// and mapped into one of these variants. `sealed` keeps the family closed
/// (exhaustive switches; no foreign variants leak in). Pure Dart: the
/// user-facing message lives in `presentation/send_failure_l10n.dart`, never
/// here.
///
/// The two nested sealed sub-families ([SendInvalidPaymentRequestFailure],
/// [SendSwapCreationFailure]) mirror the legacy exception sub-hierarchies so the
/// send state can keep one typed slot per UI zone.
sealed class SendFailure extends Failure {
  const SendFailure([super.logMessage]);
}

// --- Address step: payment-request validation -------------------------------

/// The scanned/pasted/typed string is not a payment request we can handle.
sealed class SendInvalidPaymentRequestFailure extends SendFailure {
  const SendInvalidPaymentRequestFailure([super.logMessage]);
}

final class SendInvalidPaymentRequestGenericFailure
    extends SendInvalidPaymentRequestFailure {
  const SendInvalidPaymentRequestGenericFailure([super.logMessage]);
}

/// A recognizable QR/URI shape we don't support (kept distinct so the UI can
/// tell the user the format is unsupported rather than simply invalid).
final class SendUnsupportedQrFormatFailure
    extends SendInvalidPaymentRequestFailure {
  const SendUnsupportedQrFormatFailure([super.logMessage]);
}

// --- Balance ----------------------------------------------------------------

final class SendInsufficientBalanceFailure extends SendFailure {
  const SendInsufficientBalanceFailure([super.logMessage]);
}

// --- Swap creation ----------------------------------------------------------

sealed class SendSwapCreationFailure extends SendFailure {
  const SendSwapCreationFailure([super.logMessage]);
}

final class SendSwapCreationGenericFailure extends SendSwapCreationFailure {
  const SendSwapCreationGenericFailure([super.logMessage]);
}

final class SendAmountlessInvoiceFailure extends SendSwapCreationFailure {
  const SendAmountlessInvoiceFailure([super.logMessage]);
}

final class SendExpiredInvoiceFailure extends SendSwapCreationFailure {
  const SendExpiredInvoiceFailure([super.logMessage]);
}

final class SendHardwareWalletSwapFailure extends SendSwapCreationFailure {
  const SendHardwareWalletSwapFailure([super.logMessage]);
}

// --- Swap limits ------------------------------------------------------------

/// Carries the numeric limit(s) so the presentation layer can build the
/// localized "below {min}" / "above {max}" messages; the booleans drive layout
/// only (which message, and the "use instant payments" hint). The numbers and
/// flags are UI inputs — never a raw reason string.
final class SendSwapLimitsFailure extends SendFailure {
  final int? minLimit;
  final int? maxLimit;
  final bool suggestInstantPayments;

  const SendSwapLimitsFailure({
    this.minLimit,
    this.maxLimit,
    this.suggestInstantPayments = false,
    String? logMessage,
  })  :
        // Exactly one limit is set per construction; the l10n switch matches
        // `minLimit` before `maxLimit`, so carrying both would make the
        // above-max message unreachable. Assert the invariant the switch relies on.
        assert(
          (minLimit == null) != (maxLimit == null),
          'SendSwapLimitsFailure must carry exactly one of minLimit/maxLimit',
        ),
        super(logMessage);
}

// --- Build / confirm --------------------------------------------------------

final class SendBuildTransactionFailure extends SendFailure {
  const SendBuildTransactionFailure([super.logMessage]);
}

final class SendConfirmTransactionFailure extends SendFailure {
  final bool isBroadcastFailure;

  const SendConfirmTransactionFailure({
    this.isBroadcastFailure = false,
    String? logMessage,
  }) : super(logMessage);
}

// --- Catch-all --------------------------------------------------------------

/// Generic, unexpected failure. [logMessage] is for logs ONLY and MUST never
/// reach the UI — the presentation extension returns the shared generic string.
final class SendUnexpectedFailure extends SendFailure {
  const SendUnexpectedFailure([super.logMessage]);
}
