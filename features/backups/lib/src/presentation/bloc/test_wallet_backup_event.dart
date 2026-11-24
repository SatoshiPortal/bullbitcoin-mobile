part of 'test_wallet_backup_bloc.dart';

sealed class TestWalletBackupEvent {
  const TestWalletBackupEvent();
}

class LoadWallets extends TestWalletBackupEvent {
  const LoadWallets();
}

class WalletSelected extends TestWalletBackupEvent {
  const WalletSelected({required this.wallet});
  final BackupWallet wallet;
}

/// The challenge verified the words and any passphrase for this secret.
class VerifyPhysicalBackup extends TestWalletBackupEvent {
  final PhysicalBackupProof proof;

  const VerifyPhysicalBackup(this.proof);
}

class ClearFailure extends TestWalletBackupEvent {
  const ClearFailure();
}
