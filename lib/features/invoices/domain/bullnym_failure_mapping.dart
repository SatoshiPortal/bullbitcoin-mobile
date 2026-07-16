import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';

InvoicesFailure mapBullnymFailureToInvoices(BullnymFailure failure) {
  return switch (failure.kind) {
    BullnymFailureKind.invalidInput => InvoicesFailure.invalidInput(
      code: failure.code,
      logMessage: failure.logMessage,
    ),
    BullnymFailureKind.network => const InvoicesFailure.network(),
    BullnymFailureKind.timeout => const InvoicesFailure.timeout(),
    BullnymFailureKind.serverRejectedRequest => switch (failure.code) {
      'InvoiceNotFound' => const InvoicesFailure.notFound(),
      // The server reuses the `InvalidAmount` code for EVERY create-time field
      // validation (amount, address, AND liquid_blinding_key_hex), so the code
      // alone cannot say which field was rejected. Carry the server's reason on
      // the failure's diagnostic [logMessage] (logs/Sentry only, never UI, never
      // toString) so the real cause — e.g. "liquid_blinding_key_hex: invalid
      // secret key" — is recoverable instead of collapsing to a bare amount error.
      'InvalidAmount' => InvoicesFailure.invalidInput(
        code: failure.code,
        logMessage: failure.logMessage,
      ),
      'AuthError' => const InvoicesFailure.authError(),
      'BitcoinAddressAlreadyUsed' =>
        const InvoicesFailure.reusedBitcoinAddress(),
      'LiquidAddressAlreadyUsed' => const InvoicesFailure.reusedLiquidAddress(),
      'InvoiceCreateConflict' => const InvoicesFailure.createConflict(),
      'RateLimitedSender' ||
      'RateLimitedRecipient' ||
      'RateLimitedNetwork' => const InvoicesFailure.rateLimited(),
      _ => InvoicesFailure.server(retryable: failure.retryable),
    },
    BullnymFailureKind.unexpectedHttpStatus => const InvoicesFailure.server(
      retryable: true,
    ),
    BullnymFailureKind.emptyResponse ||
    BullnymFailureKind.invalidServerResponse =>
      const InvoicesFailure.invalidServerResponse(),
    BullnymFailureKind.signingFailed => const InvoicesFailure.signingFailed(),
    BullnymFailureKind.unexpected => const InvoicesFailure.unexpected(),
  };
}
