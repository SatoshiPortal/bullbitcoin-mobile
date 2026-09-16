part of 'test_wallet_backup_bloc.dart';

sealed class TestWalletBackupEvent {
  const TestWalletBackupEvent();
}

class LoadWallets extends TestWalletBackupEvent {
  const LoadWallets();
}

class WalletSelected extends TestWalletBackupEvent {
  const WalletSelected({required this.wallet});
  final Wallet wallet;
}

/// The user re-entered their backup correctly, as judged by
/// `MnemonicChallenge`. Carries no words: the comparison happened inside the
/// secrets package.
class VerifyPhysicalBackup extends TestWalletBackupEvent {
  const VerifyPhysicalBackup();
}

class ClearError extends TestWalletBackupEvent {
  const ClearError();
}
