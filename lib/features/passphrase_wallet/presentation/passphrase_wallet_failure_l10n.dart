import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/passphrase_wallet/domain/passphrase_wallet_failure.dart';
import 'package:flutter/widgets.dart';

extension PassphraseWalletFailureL10n on PassphraseWalletFailure {
  String toTranslated(BuildContext context) => switch (this) {
    InvalidPassphraseFailure() => context.loc.passphraseWalletInvalid,
    PassphraseWalletSyncFailure() => context.loc.passphraseWalletSyncError,
    PassphraseWalletSeedFailure() ||
    PassphraseWalletManifestFailure() ||
    PassphraseWalletDescriptorFailure() ||
    PassphraseWalletConflictFailure() ||
    PassphraseWalletStorageFailure() => context.loc.passphraseWalletOpenError,
  };
}
