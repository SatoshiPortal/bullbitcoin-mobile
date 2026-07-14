import 'package:bb_mobile/core/failures/failure.dart';

sealed class TestWalletBackupFailure extends Failure {
  const TestWalletBackupFailure([super.logMessage]);
}

final class TestWalletBackupNoMnemonicFailure extends TestWalletBackupFailure {
  const TestWalletBackupNoMnemonicFailure();
}

final class TestWalletBackupIncompleteMnemonicFailure
    extends TestWalletBackupFailure {
  const TestWalletBackupIncompleteMnemonicFailure();
}

final class TestWalletBackupIncorrectOrderFailure
    extends TestWalletBackupFailure {
  const TestWalletBackupIncorrectOrderFailure();
}

final class TestWalletBackupNoWalletSelectedFailure
    extends TestWalletBackupFailure {
  const TestWalletBackupNoWalletSelectedFailure();
}

final class TestWalletBackupPersistenceFailure extends TestWalletBackupFailure {
  const TestWalletBackupPersistenceFailure([super.logMessage]);
}

final class TestWalletBackupLoadWalletsFailure extends TestWalletBackupFailure {
  const TestWalletBackupLoadWalletsFailure([super.logMessage]);
}

final class TestWalletBackupLoadMnemonicFailure
    extends TestWalletBackupFailure {
  const TestWalletBackupLoadMnemonicFailure([super.logMessage]);
}
