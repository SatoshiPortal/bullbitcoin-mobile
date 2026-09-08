import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:flutter/widgets.dart';

/// User-facing, localized message for each [TestWalletBackupFailure]. The
/// `sealed` switch makes a missing message a compile error.
///
/// Never returns `logMessage`. That matters more here than elsewhere: this
/// flow reads the wallet seed, so a raw reason could carry secret material
/// into a snackbar.
extension TestWalletBackupFailureL10n on TestWalletBackupFailure {
  String toTranslated(BuildContext context) => switch (this) {
    TestWalletBackupWalletsUnavailableFailure() =>
      context.loc.testBackupErrorWalletsUnavailable,
    TestWalletBackupNoWalletsFailure() => context.loc.testBackupErrorNoWallets,
    TestWalletBackupNoWalletSelectedFailure() =>
      context.loc.testBackupErrorNoWalletSelected,
    TestWalletBackupSeedUnavailableFailure() =>
      context.loc.testBackupErrorSeedUnavailable,
    TestWalletBackupSeedNotMnemonicFailure() =>
      context.loc.testBackupErrorSeedNotMnemonic,
    TestWalletBackupCompletionFailure() =>
      context.loc.testBackupErrorCompletionFailed,
    TestWalletBackupUnexpectedFailure() => context.loc.oopsSomethingWentWrong,
  };
}
