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

class StartBackupTesting extends TestWalletBackupEvent {
  const StartBackupTesting({
    required this.backupKey,
    required this.backupFile,
  });
  final String backupKey;
  final String backupFile;
}

class StartTransitioning extends TestWalletBackupEvent {
  const StartTransitioning();
}

class EndTransitioning extends TestWalletBackupEvent {
  const EndTransitioning();
}
