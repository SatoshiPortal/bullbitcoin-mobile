import 'package:flutter/widgets.dart';
import 'package:provisioning/provisioning.dart';

import '../onboarding_l10n.dart';

extension NetworkWalletSetupFailureL10n on NetworkWalletSetupFailure {
  String toTranslated(BuildContext context) => switch (this) {
    NetworkWalletSetupSecretFailure(:final reason) => switch (reason) {
      DefaultWalletSecretRefusal.nonMnemonic =>
        context.loc.networkWalletReuseNoRecoveryPhrase,
    },
    NetworkWalletSetupContextFailure() => context.loc.networkFeatureUnavailable,
    NetworkWalletSetupReferenceNotFoundFailure() =>
      context.loc.walletDeletionErrorWalletNotFound,
    NetworkWalletSetupStorageFailure() ||
    NetworkWalletSetupUnavailableFailure() => context.loc.walletLoadFailed,
    NetworkWalletSetupBackupRequiredFailure() =>
      context.loc.networkWalletBackupRequired,
  };
}
