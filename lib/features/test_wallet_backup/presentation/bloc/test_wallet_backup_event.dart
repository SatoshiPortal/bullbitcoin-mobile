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

class VerifyPhysicalBackup extends TestWalletBackupEvent {
  const VerifyPhysicalBackup({required this.reorderedWords});
  final List<String> reorderedWords;
}

class ClearError extends TestWalletBackupEvent {
  const ClearError();
}
