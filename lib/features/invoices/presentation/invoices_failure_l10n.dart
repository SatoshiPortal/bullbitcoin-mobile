import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/invoices/domain/invoices_failure.dart';
import 'package:flutter/widgets.dart';

/// Localized presentation copy for [InvoicesFailure]. Diagnostic details stay
/// in `logMessage` and are never rendered to the user.
extension InvoicesFailureL10n on InvoicesFailure {
  String toTranslated(BuildContext context) => switch (this) {
    InvoicesNoDefaultBitcoinWalletFailure() =>
      context.loc.invoiceErrorNoDefaultBitcoinWallet,
    InvoicesNoDefaultLiquidWalletFailure() =>
      context.loc.invoiceErrorNoDefaultLiquidWallet,
    InvoicesInvalidInputFailure() => context.loc.invoiceErrorInvalidInput,
    InvoicesReusedBitcoinAddressFailure() ||
    InvoicesReusedLiquidAddressFailure() =>
      context.loc.invoiceErrorReusedAddress,
    InvoicesNotFoundFailure() => context.loc.invoiceErrorNotFound,
    InvoicesAuthFailure() => context.loc.invoiceErrorAuth,
    InvoicesRateLimitedFailure() => context.loc.invoiceErrorRateLimited,
    InvoicesNetworkFailure() ||
    InvoicesTimeoutFailure() => context.loc.invoiceErrorConnection,
    InvoicesPrivateStorageFailure() => context.loc.invoiceErrorPrivateStorage,
    InvoicesEncryptionFailure() => context.loc.invoiceErrorEncryption,
    InvoicesOutcomeUnknownFailure() => context.loc.invoiceErrorOutcomeUnknown,
    InvoicesCreateConflictFailure() => context.loc.invoiceErrorCreateConflict,
    InvoicesServerFailure() => context.loc.invoiceErrorServer,
    InvoicesInvalidServerResponseFailure() ||
    InvoicesSigningFailedFailure() ||
    InvoicesUnexpectedFailure() => context.loc.invoiceErrorUnexpected,
  };
}
