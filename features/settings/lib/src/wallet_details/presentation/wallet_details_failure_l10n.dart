import 'package:flutter/widgets.dart';

import '../../../generated/l10n/settings_localizations.dart';
import '../domain/wallet_details_failure.dart';

/// Every deletion failure has a user message; only the refusals carry their
/// own wording, and the reason itself stays in the log.
extension WalletDetailsFailureL10n on WalletDetailsFailure {
  String toTranslated(BuildContext context) {
    final loc = SettingsLocalizations.of(context);
    return switch (this) {
      WalletDetailsDefaultFailure() => loc.walletDeletionErrorDefaultWallet,
      WalletDetailsOngoingSwapsFailure() => loc.walletDeletionErrorOngoingSwaps,
      WalletDetailsNotFoundFailure() => loc.walletDeletionErrorWalletNotFound,
      WalletDetailsDiscoveryFailure() => loc.walletDiscoveryFailed,
      WalletDetailsUnavailableFailure() => loc.walletDeletionErrorGeneric,
    };
  }
}
