import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/wallet/domain/default_wallet_secret_policy.dart';
import 'package:bb_mobile/features/wallet/domain/network_wallet_setup_failure.dart';
import 'package:bb_mobile/features/wallet/presentation/wallet_failure_l10n.dart';
import 'package:flutter/widgets.dart';

extension NetworkWalletSetupFailureL10n on NetworkWalletSetupFailure {
  String toTranslated(BuildContext context) => switch (this) {
    NetworkWalletSetupSecretFailure(:final reason) => switch (reason) {
      DefaultWalletSecretRefusal.nonMnemonic =>
        context.loc.mnemonicDefaultEnglishOnly,
      DefaultWalletSecretRefusal.passphrase =>
        context.loc.networkFeatureUnavailable,
    },
    NetworkWalletSetupContextFailure() => context.loc.networkFeatureUnavailable,
    NetworkWalletSetupReadFailure(:final failure) => failure.toTranslated(
      context,
    ),
    NetworkWalletSetupUnavailableFailure() => context.loc.walletLoadFailed,
  };
}
