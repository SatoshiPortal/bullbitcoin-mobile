part of 'test_wallet_backup_bloc.dart';

sealed class TestWalletBackupEvent {
  const TestWalletBackupEvent();
}

class OnWordsSelected extends TestWalletBackupEvent {
  const OnWordsSelected({required this.word, required this.index});
  final String word;
  final int index;
}

class StartPhysicalBackupVerification extends TestWalletBackupEvent {
  const StartPhysicalBackupVerification();
}

class VerifyPhysicalBackup extends TestWalletBackupEvent {
  const VerifyPhysicalBackup();
}

class LoadWallets extends TestWalletBackupEvent {
  const LoadWallets();
}

class LoadMnemonicForWallet extends TestWalletBackupEvent {
  const LoadMnemonicForWallet({required this.wallet});
  final Wallet wallet;
}

class ClearError extends TestWalletBackupEvent {
  const ClearError();
}
