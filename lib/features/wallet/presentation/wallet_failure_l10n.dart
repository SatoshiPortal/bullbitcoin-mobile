import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter/widgets.dart';

/// The wallet feature's rendering of a [WalletFailure]: the home screen,
/// where a failure describes loading or syncing.
///
/// The deletion sheet lives in settings and has its own rendering there
/// (`WalletDeletionFailureL10n`) — same core-owned family, but a different
/// verb and remedy per context, and settings must not import this feature's
/// presentation internals.
///
/// The switch is exhaustive over the sealed family, so a new variant without
/// a user message is a compile error.
extension WalletFailureL10n on WalletFailure {
  String toTranslated(BuildContext context) => switch (this) {
    WalletCannotDeleteDefaultFailure() =>
      context.loc.walletDeletionErrorDefaultWallet,
    WalletCannotDeleteWithOngoingSwapsFailure() =>
      context.loc.walletDeletionErrorOngoingSwaps,
    WalletNotFoundFailure() => context.loc.walletDeletionErrorWalletNotFound,
    // The list loaded; only the sync behind it failed. Saying "could not be
    // loaded" above a visibly loaded list would contradict the screen.
    WalletSyncFailure() => context.loc.walletBalancesMayBeStale,
    WalletStorageFailure() ||
    WalletTransactionLookupFailure() ||
    WalletLwkStatusConflictFailure() ||
    NoWalletsFoundFailure() => context.loc.walletLoadFailed,
    // Never `logMessage`: the reason is for the log, not the screen.
    WalletUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
