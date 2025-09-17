part of 'test_wallet_backup_bloc.dart';

sealed class TestWalletBackupEvent {
  const TestWalletBackupEvent();
}

class SelectGoogleDriveBackupTest extends TestWalletBackupEvent {
  const SelectGoogleDriveBackupTest();
}

class SelectFileSystemBackupTes extends TestWalletBackupEvent {
  const SelectFileSystemBackupTes();
}

class StartVaultBackupTesting extends TestWalletBackupEvent {
  const StartVaultBackupTesting({required this.vaultKey, required this.vault});
  final String vaultKey;
  final EncryptedVault vault;
}

class OnWordsSelected extends TestWalletBackupEvent {
  const OnWordsSelected({required this.shuffledIdx});
  final int shuffledIdx;
}

class StartPhysicalBackupVerification extends TestWalletBackupEvent {
  const StartPhysicalBackupVerification();
}

class VerifyPhysicalBackup extends TestWalletBackupEvent {
  const VerifyPhysicalBackup();
}

class StartTransitioning extends TestWalletBackupEvent {
  const StartTransitioning();
}

class EndTransitioning extends TestWalletBackupEvent {
  const EndTransitioning();
}

class LoadWallets extends TestWalletBackupEvent {
  const LoadWallets();
}

class LoadMnemonicForWallet extends TestWalletBackupEvent {
  const LoadMnemonicForWallet({required this.wallet});
  final Wallet wallet;
}
