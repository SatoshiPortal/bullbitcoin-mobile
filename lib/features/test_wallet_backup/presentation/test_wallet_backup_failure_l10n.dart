import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/test_wallet_backup_failure.dart';
import 'package:flutter/widgets.dart';

extension TestWalletBackupFailureL10n on TestWalletBackupFailure {
  String toTranslated(BuildContext context) => switch (this) {
    TestWalletBackupNoMnemonicFailure() =>
      context.loc.testBackupErrorNoMnemonic,
    TestWalletBackupIncompleteMnemonicFailure() =>
      context.loc.testBackupErrorSelectAllWords,
    TestWalletBackupIncorrectOrderFailure() =>
      context.loc.testBackupErrorIncorrectOrder,
    TestWalletBackupNoWalletSelectedFailure() =>
      context.loc.testBackupErrorNoWalletSelected,
    TestWalletBackupPersistenceFailure() =>
      context.loc.testBackupErrorVerificationFailedGeneric,
    TestWalletBackupLoadWalletsFailure() =>
      context.loc.testBackupErrorLoadWalletsGeneric,
    TestWalletBackupLoadMnemonicFailure() =>
      context.loc.testBackupErrorLoadMnemonicGeneric,
  };
}
