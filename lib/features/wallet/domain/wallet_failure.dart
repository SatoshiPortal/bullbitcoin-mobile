import 'package:primitives/primitives.dart' show Failure;

sealed class WalletFailure extends Failure {
  const WalletFailure([super.logMessage]);
}

final class WalletTransactionLookupFailure extends WalletFailure {
  const WalletTransactionLookupFailure([super.logMessage]);
}

/// Reading or writing the wallet store failed.
final class WalletStorageFailure extends WalletFailure {
  const WalletStorageFailure([super.logMessage]);
}

/// No wallet exists for the given id.
final class WalletNotFoundFailure extends WalletFailure {
  const WalletNotFoundFailure([super.logMessage]);
}

/// No wallet matched the query.
///
/// Usually "the user has not finished onboarding" — the wallet home reads it
/// that way and the router redirects. But it is also returned for any empty
/// filtered result, so a caller asking for liquid-only wallets on a
/// bitcoin-only install gets this too. Not an error condition to report.
final class NoWalletsFoundFailure extends WalletFailure {
  const NoWalletsFoundFailure([super.logMessage]);
}

/// The default wallet cannot be deleted.
final class WalletCannotDeleteDefaultFailure extends WalletFailure {
  const WalletCannotDeleteDefaultFailure([super.logMessage]);
}

/// A swap is still in flight on this wallet, so deleting it would strand funds.
final class WalletCannotDeleteWithOngoingSwapsFailure extends WalletFailure {
  const WalletCannotDeleteWithOngoingSwapsFailure([super.logMessage]);
}

/// A sync round did not complete.
///
/// Distinct from a read failure: the wallets on screen are still valid, the
/// balances behind them are just not fresh.
final class WalletSyncFailure extends WalletFailure {
  const WalletSyncFailure([super.logMessage]);
}

/// LWK refused the update because its stored status disagrees with the chain.
///
/// A status conflict requires reconciliation by the native wallet writer.
/// Readers preserve the store and propagate this failure without deleting it.
final class WalletLwkStatusConflictFailure extends WalletFailure {
  const WalletLwkStatusConflictFailure([super.logMessage]);
}

/// The catch-all. Carries a developer reason for the log only: the user sees a
/// generic message, never [logMessage].
final class WalletUnexpectedFailure extends WalletFailure {
  const WalletUnexpectedFailure([super.logMessage]);
}

/// Routine contention is unsuccessful but does not imply a server outage.
final class WalletSyncBusyFailure extends WalletFailure {
  const WalletSyncBusyFailure();
}

/// An explicit selection is empty or a selected coin is no longer spendable.
final class WalletSelectedInputsUnavailableFailure extends WalletFailure {
  const WalletSelectedInputsUnavailableFailure([super.logMessage]);
}

final class WalletNoSpendableInputsFailure extends WalletFailure {
  const WalletNoSpendableInputsFailure([super.logMessage]);
}

final class WalletInsufficientFundsFailure extends WalletFailure {
  const WalletInsufficientFundsFailure([super.logMessage]);
}

final class WalletTransactionBuildFailure extends WalletFailure {
  const WalletTransactionBuildFailure([super.logMessage]);
}

final class WalletConsolidationRequiredFailure extends WalletFailure {
  const WalletConsolidationRequiredFailure([super.logMessage]);
}

/// A recipient address does not belong to the wallet's network.
final class WalletAddressNetworkMismatchFailure extends WalletFailure {
  const WalletAddressNetworkMismatchFailure([super.logMessage]);
}
