import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter/widgets.dart';

/// Settings' rendering of a [WalletFailure], for the wallet-deletion sheet.
///
/// Lives here and not next to the wallet feature's `toTranslated` because the
/// sheet is settings UI: importing another feature's `presentation/` would
/// cross a facade boundary. The family itself is core-owned, so any feature
/// may translate it in its own presentation layer.
///
/// Every failure here is a failure *to delete*. Only the refusals carry their
/// own wording; everything else is the generic deletion message rather than a
/// load or connectivity one — telling a user to check their connection because
/// a local delete failed would be both the wrong verb and the wrong remedy.
/// The switch is exhaustive over the sealed family, so a new variant without a
/// deletion message is a compile error.
extension WalletDeletionFailureL10n on WalletFailure {
  String toDeletionTranslated(BuildContext context) => switch (this) {
    WalletCannotDeleteDefaultFailure() =>
      context.loc.walletDeletionErrorDefaultWallet,
    WalletCannotDeleteWithOngoingSwapsFailure() =>
      context.loc.walletDeletionErrorOngoingSwaps,
    WalletNotFoundFailure() => context.loc.walletDeletionErrorWalletNotFound,
    WalletStorageFailure() ||
    WalletTransactionLookupFailure() ||
    WalletLwkStatusConflictFailure() ||
    WalletSyncFailure() ||
    NoWalletsFoundFailure() ||
    // Never `logMessage`: the reason is for the log, not the screen.
    WalletUnexpectedFailure() => context.loc.walletDeletionErrorGeneric,
  };
}
