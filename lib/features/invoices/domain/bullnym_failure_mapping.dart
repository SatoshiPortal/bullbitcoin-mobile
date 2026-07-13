import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';

InvoicesFailure mapBullnymFailureToInvoices(BullnymFailure failure) {
  return switch (failure.kind) {
    BullnymFailureKind.invalidInput => InvoicesFailure.invalidInput(
      code: failure.code,
    ),
    BullnymFailureKind.network => const InvoicesFailure.network(),
    BullnymFailureKind.timeout => const InvoicesFailure.timeout(),
    BullnymFailureKind.serverRejectedRequest => switch (failure.code) {
      'InvoiceNotFound' => const InvoicesFailure.notFound(),
      'InvalidAmount' => InvoicesFailure.invalidInput(code: failure.code),
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
